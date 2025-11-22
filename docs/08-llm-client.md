# LLM Client - Quản lý kết nối với Gemini API

## Vị trí trong flow

LLM Client được sử dụng ở nhiều điểm trong pipeline:

```
QueryWriting → LLM Client (query_writing)
SmartSearch → LLM Client (generate)
SpokeExecutor → LLM Client (filter_nodes) [optional]
AnswerGenerator → LLM Client (generate_text)
```

## Mục đích

Quản lý tất cả các tương tác với Gemini API, bao gồm:
1. Rate limiting (proactive)
2. Retry logic (reactive)
3. Model selection (pro vs flash)
4. Error handling

## File liên quan

- `modules/llm_client.py`: Module GeminiLLMClient

## Kiến trúc

### Class hierarchy

```
BaseLLMClient (ABC)
    └─ GeminiLLMClient (implementation)
```

### Models được sử dụng

1. **gemini-2.5-pro** (`model_main`):
   - Dùng cho: Planning, Answer Generation
   - Max retries: 2
   - Rate limit: 2 RPM

2. **gemini-2.0-flash** (`model_sub`):
   - Dùng cho: Query Writing
   - Max retries: 10
   - Không có rate limit (vì ít được gọi)

3. **gemini-2.0-flash** (`model_filter`):
   - Dùng cho: Node Pruning
   - Max retries: 10
   - Không có rate limit

## Chi tiết xử lý

### 1. Khởi tạo

```python
client = GeminiLLMClient(
    api_key=gemini_key,
    max_retries_main=2,
    max_retries_sub=10,
    rpm_limit=2
)
```

**Parameters**:
- `api_key`: Gemini API key từ .env
- `max_retries_main`: Số lần retry cho model_main (default: 2)
- `max_retries_sub`: Số lần retry cho model_sub/filter (default: 10)
- `rpm_limit`: Requests per minute limit (default: 2)

**Initialization**:
```python
genai.configure(api_key=api_key)
self.model_main = genai.GenerativeModel("gemini-2.5-pro")
self.model_sub = genai.GenerativeModel("gemini-2.0-flash")
self.model_filter = genai.GenerativeModel("gemini-2.0-flash")
self.request_timestamps: List[float] = []
self.lock = threading.Lock()
```

### 2. Rate Limiting (Proactive)

**Function**: `_wait_for_rate_limit()`

**Mục đích**: Chờ trước khi gọi API để không vi phạm RPM limit.

**Cơ chế**:
1. Track timestamps của các requests trong 60 giây gần nhất
2. Nếu số requests >= `rpm_limit`, chờ cho đến khi có slot trống
3. Tính thời gian chờ: `(oldest_request_time + 60.1) - now`

**Code**:
```python
def _wait_for_rate_limit(self):
    with self.lock:
        now = time.time()
        # Xóa các timestamp cũ (hơn 60 giây)
        self.request_timestamps = [t for t in self.request_timestamps if now - t < 60]
        
        # Chờ nếu đã đạt limit
        while len(self.request_timestamps) >= self.rpm_limit:
            oldest_request_time = self.request_timestamps[0]
            wait_duration = (oldest_request_time + 60.1) - now
            
            if wait_duration > 0:
                print(f"Proactive rate limit: {len(self.request_timestamps)} requests in last 60s. "
                      f"Waiting for {wait_duration:.2f}s...")
                time.sleep(wait_duration)
            
            now = time.time()
            self.request_timestamps = [t for t in self.request_timestamps if now - t < 60]
        
        # Ghi lại timestamp của request sắp được thực hiện
        self.request_timestamps.append(time.time())
```

**Ví dụ**:
- RPM limit: 2
- Request 1: t=0s → OK
- Request 2: t=5s → OK
- Request 3: t=10s → Chờ đến t=60.1s (vì request 1 sẽ expire)

**Lưu ý**: Chỉ áp dụng cho `model_main` (planning và answer generation).

### 3. Retry Logic (Reactive)

**Function**: `_generate_with_retry()`

**Mục đích**: Xử lý lỗi `ResourceExhausted` (rate limit exceeded) từ API.

**Cơ chế**:
1. Gọi API
2. Nếu gặp `ResourceExhausted`, đọc thời gian chờ từ error message
3. Chờ theo thời gian API yêu cầu + 0.5s buffer
4. Retry cho đến khi hết max_retries

**Code**:
```python
async def _generate_with_retry(self, model: Any, max_retries: int, prompt: str, is_json: bool) -> str:
    retries = 0
    gen_config = {
        "temperature": 0,
    }
    if is_json:
        gen_config["response_mime_type"] = "application/json"
    
    while retries < max_retries:
        try:
            response = model.generate_content(
                prompt,
                generation_config=gen_config
            )
            return response.text.strip()
        
        except ResourceExhausted as e:
            retries += 1
            if retries >= max_retries:
                raise e
            
            # Đọc thời gian chờ từ error message
            error_message = str(e)
            match = re.search(r"Please retry in (\d+\.?\d*)s", error_message)
            
            wait_time = 15.0  # Default
            if match:
                try:
                    wait_time = float(match.group(1)) + 0.5  # +0.5s buffer
                except (ValueError, IndexError):
                    pass
            
            print(f"Warning: Reactive retry (attempt {retries}/{max_retries}). "
                  f"API requested retry in {wait_time:.2f}s...")
            time.sleep(wait_time)
        
        except Exception as e:
            print(f"Error: An unexpected error occurred calling Gemini: {e}")
            raise e
    
    return '{"error": "Gemini API call failed after retries"}' if is_json else "Error: Gemini call failed"
```

**Ví dụ error message**:
```
ResourceExhausted: 429 Quota exceeded for quota metric 'Requests per minute' 
and limit '2 per minute' of service 'generativelanguage.googleapis.com' 
for consumer 'project_number:123456'. Please retry in 45.2s.
```

→ Extract "45.2s" → Chờ 45.7s (45.2 + 0.5)

### 4. Các methods

#### 4.1. query_writing()

**Mục đích**: Rewrite query (QueryWriting module)

**Model**: `model_sub` (flash)
**Max retries**: `max_retries_sub` (10)
**Rate limit**: Không (vì dùng flash và ít được gọi)
**Output**: Plain text

```python
async def query_writing(self, prompt: str) -> str:
    print(f"[LLM_TEXT_INPUT] (Length: {len(prompt)} chars)")
    try:
        return await self._generate_with_retry(
            self.model_sub, 
            self.max_retries_sub, 
            prompt, 
            is_json=False
        )
    except Exception as e:
        print(f"Error in query_writing(): {e}")
        return "An error occurred while trying to generate a response."
```

#### 4.2. generate()

**Mục đích**: Generate JSON plan (SmartSearch module)

**Model**: `model_main` (pro)
**Max retries**: `max_retries_main` (2)
**Rate limit**: Có (`_wait_for_rate_limit()`)
**Output**: JSON string

```python
async def generate(self, prompt: str) -> str:
    # Chờ rate limit
    self._wait_for_rate_limit()
    
    print(f"[LLM_JSON_INPUT] (Length: {len(prompt)} chars)")
    try:
        raw_json_string = await self._generate_with_retry(
            self.model_main, 
            self.max_retries_main, 
            prompt, 
            is_json=True
        )
        
        # Validate JSON
        try:
            json.loads(raw_json_string)
        except json.JSONDecodeError:
            print("Warning: Gemini returned non-JSON, wrapping it.")
            raw_json_string = json.dumps({"output": raw_json_string})
        
        return raw_json_string
    except Exception as e:
        print(f"Error in generate(): {e}")
        return '{"error": "Gemini API call failed"}'
```

#### 4.3. filter_nodes()

**Mục đích**: Prune nodes (SpokeExecutor module)

**Model**: `model_filter` (flash)
**Max retries**: `max_retries_sub` (10)
**Rate limit**: Không
**Output**: JSON string

```python
async def filter_nodes(self, prompt: str) -> str:
    print(f"[LLM_JSON_INPUT] (Length: {len(prompt)} chars)")
    try:
        raw_json_string = await self._generate_with_retry(
            self.model_filter, 
            self.max_retries_sub, 
            prompt, 
            is_json=True
        )
        
        # Validate JSON
        try:
            json.loads(raw_json_string)
        except json.JSONDecodeError:
            print("Warning: Gemini returned non-JSON, wrapping it.")
            raw_json_string = json.dumps({"output": raw_json_string})
        
        return raw_json_string
    except Exception as e:
        print(f"Error in filter_nodes(): {e}")
        return '{"error": "Gemini API call failed"}'
```

#### 4.4. generate_text()

**Mục đích**: Generate final answer (AnswerGenerator module)

**Model**: `model_main` (pro)
**Max retries**: `max_retries_main` (2)
**Rate limit**: Có (`_wait_for_rate_limit()`)
**Output**: Plain text

```python
async def generate_text(self, prompt: str) -> str:
    # Chờ rate limit
    self._wait_for_rate_limit()
    
    print(f"[LLM_TEXT_INPUT] (Length: {len(prompt)} chars)")
    try:
        return await self._generate_with_retry(
            self.model_main, 
            self.max_retries_main, 
            prompt, 
            is_json=False
        )
    except Exception as e:
        print(f"Error in generate_text(): {e}")
        return "An error occurred while trying to generate a response."
```

## Rate Limiting Strategy

### Proactive (Trước khi gọi)

- **Áp dụng cho**: `model_main` (planning và answer generation)
- **Cơ chế**: Track timestamps, chờ trước khi gọi
- **Mục đích**: Tránh vi phạm limit ngay từ đầu

### Reactive (Sau khi gặp lỗi)

- **Áp dụng cho**: Tất cả models
- **Cơ chế**: Đọc wait time từ error message, retry
- **Mục đích**: Xử lý khi vẫn bị rate limit

## Thread Safety

Rate limiting sử dụng `threading.Lock()` để đảm bảo thread-safe:

```python
self.lock = threading.Lock()

def _wait_for_rate_limit(self):
    with self.lock:
        # ... rate limiting logic
```

## Error Handling

### ResourceExhausted

- Được xử lý bằng retry logic
- Đọc wait time từ error message
- Retry với exponential backoff (dựa trên API response)

### JSON Decode Error

- Nếu LLM trả về non-JSON, wrap vào JSON object
- `{"output": raw_string}`

### Other Exceptions

- Log error và return error message
- Không throw exception để không crash server

## Logging

Module log:
- `[LLM_TEXT_INPUT]` hoặc `[LLM_JSON_INPUT]` với prompt length
- Rate limiting messages
- Retry attempts
- Error messages

## Lưu ý quan trọng

1. **Shared instance**: Tất cả modules dùng chung một LLM client instance
2. **Rate limit chỉ cho model_main**: Query writing và pruning không có rate limit
3. **Thread-safe**: Rate limiting sử dụng lock để đảm bảo thread-safe
4. **Fail-safe**: Nếu API call fail, trả về error message thay vì throw exception
5. **Smart retry**: Đọc wait time từ API response thay vì hardcode

## Performance Considerations

- **Model selection**: Pro cho tasks quan trọng, flash cho tasks đơn giản
- **Rate limiting**: Proactive để tránh waste retries
- **Retry strategy**: Smart retry với wait time từ API
- **Caching**: Không có (mỗi request là unique)

