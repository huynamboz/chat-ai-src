# WebSocket Endpoint - Nhận và xử lý request

## Vị trí trong flow

Đây là điểm đầu tiên của hệ thống, nơi nhận kết nối và request từ client.

## File liên quan

- `server_ai_main.py`: Định nghĩa WebSocket endpoint và handler

## Chi tiết xử lý

### 1. Khởi tạo Server

Khi server khởi động, các module được khởi tạo một lần duy nhất:

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Khởi tạo các module:
    # - GeminiLLMClient
    # - QueryWriting
    # - SmartSearch
    # - SpokeExecutor
    # - AnswerGenerator
```

**Lưu ý**: Tất cả modules được khởi tạo với cùng một `GeminiLLMClient` instance để tái sử dụng.

### 2. WebSocket Endpoint

**Endpoint**: `/ws/query`

**Method**: WebSocket connection

**Code location**: `server_ai_main.py` - hàm `websocket_endpoint()`

### 3. Quy trình xử lý request

```
┌─────────────────┐
│  Client connects│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Accept WebSocket│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Receive JSON     │
│ {                │
│   "question": "",│
│   "history": []  │
│ }                │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Validate input   │
│ - Check question │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Call pipeline    │
│ run_full_pipeline│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Send response    │
│ {                │
│   "answer": ""   │
│ }                │
└─────────────────┘
```

### 4. Chi tiết code

#### 4.1. Accept connection

```python
await websocket.accept()
logging.info("WebSocket connection established.")
```

#### 4.2. Nhận dữ liệu

```python
data = await websocket.receive_json()
question = data.get("question")
history = data.get("history", [])
```

**Format input**:
```json
{
  "question": "What are the symptoms of Alzheimer's Disease?",
  "history": [
    {"role": "user", "content": "Tell me about Alzheimer's"},
    {"role": "assistant", "content": "Alzheimer's Disease is..."}
  ]
}
```

#### 4.3. Validation

```python
if not question:
    await websocket.send_json({"error": "No question provided"})
    continue
```

#### 4.4. Gọi pipeline

```python
answer = await run_full_pipeline(question, history)
```

Pipeline này sẽ thực hiện toàn bộ quy trình xử lý (xem các file docs khác).

#### 4.5. Gửi response

```python
await websocket.send_json({"answer": answer})
```

**Format output**:
```json
{
  "answer": "Based on the data, Alzheimer's Disease is associated with symptoms such as Memory Loss, Confusion, and Difficulty with Problem Solving..."
}
```

### 5. Xử lý lỗi

#### 5.1. WebSocket disconnect

```python
except WebSocketDisconnect:
    logging.info("WebSocket connection closed.")
```

#### 5.2. Lỗi trong pipeline

```python
except Exception as e:
    logging.error(f"An error occurred in the WebSocket connection: {e}")
    try:
        await websocket.send_json({"error": f"Server error: {str(e)}"})
    except RuntimeError:
        pass  # Connection already closed
```

### 6. Logging

Tất cả các sự kiện quan trọng được ghi log:
- Kết nối WebSocket được thiết lập
- Nhận được question
- Gửi answer
- Lỗi xảy ra

### 7. Lưu ý quan trọng

1. **Connection persistent**: WebSocket connection được giữ mở để có thể nhận nhiều câu hỏi liên tiếp
2. **Async processing**: Mỗi câu hỏi được xử lý bất đồng bộ, không block các request khác
3. **Error handling**: Lỗi được catch và gửi về client dưới dạng JSON với key `error`
4. **History support**: History được truyền vào pipeline để hỗ trợ query rewriting

### 8. Ví dụ sử dụng

**Client code (Python)**:
```python
import asyncio
import websockets
import json

async def test_client():
    uri = "ws://localhost:8001/ws/query"
    async with websockets.connect(uri) as websocket:
        # Gửi câu hỏi
        await websocket.send(json.dumps({
            "question": "What genes are associated with Alzheimer's Disease?",
            "history": []
        }))
        
        # Nhận câu trả lời
        response = await websocket.recv()
        data = json.loads(response)
        print(data["answer"])
```

