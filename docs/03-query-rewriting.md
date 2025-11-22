# Query Rewriting - Chuyển đổi câu hỏi thành standalone question

## Vị trí trong flow

Đây là bước đầu tiên trong pipeline xử lý, sau khi nhận được question từ WebSocket endpoint.

```
WebSocket → QueryWriting → SmartSearch → SpokeExecutor → AnswerGenerator
```

## Mục đích

Chuyển đổi câu hỏi follow-up (có tham chiếu đến câu hỏi trước) thành một câu hỏi độc lập, tự chứa đầy đủ ngữ cảnh.

## File liên quan

- `modules/query_writing.py`: Module QueryWriting
- `modules/llm_client.py`: LLM client để gọi Gemini API

## Ví dụ

### Input:
- **Question**: "What are its symptoms?"
- **History**: 
  ```json
  [
    {"role": "user", "content": "Tell me about Alzheimer's Disease"},
    {"role": "assistant", "content": "Alzheimer's Disease is a neurodegenerative disorder..."}
  ]
  ```

### Output:
- **Standalone question**: "What are the symptoms of Alzheimer's Disease?"

## Chi tiết xử lý

### 1. Khởi tạo module

```python
query_writing = QueryWriting(
    llm_client=main_llm_client  # Shared LLM client instance
)
```

Module được khởi tạo một lần khi server start, sử dụng chung LLM client với các module khác.

### 2. Format history

**Function**: `_format_history_for_prompt()`

Chuyển đổi history từ list of dicts sang string format:

```python
def _format_history_for_prompt(history: list) -> str:
    formatted_lines = []
    for msg in history:
        role = msg.get("role", "unknow").capitalize()
        content = msg.get("content", "")
        formatted_lines.append(f"{role}: {content}")
    return "\n".join(formatted_lines)
```

**Ví dụ output**:
```
User: Tell me about Alzheimer's Disease
Assistant: Alzheimer's Disease is a neurodegenerative disorder...
```

### 3. Tạo prompt cho LLM

**Function**: `get_standalone_question()`

Prompt được tạo với các thành phần:

1. **Role**: Expert query rewriter
2. **Task**: Transform question thành standalone question
3. **Rules**:
   - Nếu question đã self-contained → giữ nguyên
   - Nếu là follow-up → rewrite sử dụng context từ history
   - Output chỉ là question, không có giải thích

**Prompt template**:
```
You are an expert query rewriter. Your task is to transform the 'New Question' 
into a single, standalone, and contextually complete question. Use the 'Chat History' 
to understand the context and resolve any references, pronouns (like 'it', 'its', 'they', 'that'), 
or ambiguities. 

**Rules:** 
1. If the 'New Question' is already self-contained and clear (e.g., "What are the side effects of Aspirin?"), 
   return it exactly as it is. 
2. If the 'New Question' is a follow-up (e.g., "What are its symptoms?"), 
   rewrite it using context from the history (e.g., "What are the symptoms of Breast Cancer?"). 
3. Your output MUST be **only** the rewritten question. Do not add any conversational text, 
   explanations, or labels like "Standalone Question:". 

**Chat History:** 
{formatted_history}

**New Question:** 
{question}
```

### 4. Gọi LLM

**Function**: `llm_client.query_writing()`

- **Model**: `gemini-2.0-flash` (model_sub)
- **Max retries**: 10 (max_retries_sub)
- **Output**: Plain text (không phải JSON)

**Code**:
```python
final_standalone_question = await self.llm_client.query_writing(final_prompt)
```

### 5. Xử lý kết quả

- Nếu thành công: Trả về standalone question
- Nếu lỗi: Trả về error message

```python
try:
    final_standalone_question = await self.llm_client.query_writing(final_prompt)
    return final_standalone_question
except Exception as e:
    print(f"Error when generating final answer: {e}")
    return "An error occurred while trying to generate the final answer."
```

## Các trường hợp xử lý

### Trường hợp 1: Câu hỏi đã standalone

**Input**:
- Question: "What are the side effects of Aspirin?"
- History: []

**Output**: "What are the side effects of Aspirin?" (giữ nguyên)

### Trường hợp 2: Câu hỏi follow-up với đại từ

**Input**:
- Question: "What are its symptoms?"
- History: [{"role": "user", "content": "Tell me about Breast Cancer"}]

**Output**: "What are the symptoms of Breast Cancer?"

### Trường hợp 3: Câu hỏi follow-up với tham chiếu ngầm

**Input**:
- Question: "How is it treated?"
- History: [{"role": "user", "content": "What is Diabetes?"}, {"role": "assistant", "content": "Diabetes is..."}]

**Output**: "How is Diabetes treated?"

## Lưu ý quan trọng

1. **Không có history**: Nếu history rỗng, LLM vẫn có thể xử lý nếu question đã standalone
2. **Error handling**: Nếu LLM call fail, module trả về error message nhưng không throw exception
3. **Output format**: LLM được yêu cầu chỉ trả về question, không có label hay giải thích
4. **Performance**: Sử dụng model flash (nhanh hơn) vì task này đơn giản hơn planning và answer generation

## Logging

Module log các thông tin:
- "---- Rewriting query ----" khi bắt đầu xử lý
- Error messages nếu có lỗi

## Kết quả

Standalone question được trả về và truyền vào bước tiếp theo: **SmartSearch (Planning)**.

