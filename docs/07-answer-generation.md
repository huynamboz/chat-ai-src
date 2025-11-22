# Answer Generation - Tạo câu trả lời tự nhiên từ dữ liệu

## Vị trí trong flow

Bước cuối cùng trong pipeline:

```
QueryWriting → SmartSearch → SpokeExecutor → AnswerGenerator → Response
```

## Mục đích

Tổng hợp dữ liệu đã thu thập từ SPOKE API và tạo ra câu trả lời tự nhiên, dễ hiểu, kèm theo giải thích về cách tìm ra câu trả lời.

## File liên quan

- `modules/generate_answer.py`: Module AnswerGenerator
- `modules/llm_client.py`: LLM client để gọi Gemini API

## Ví dụ

### Input (Context Store):
```json
{
  "diseases_list": [
    {
      "data": {
        "properties": {
          "name": "Alzheimer's Disease"
        }
      }
    }
  ],
  "genes_list": [
    {
      "data": {
        "properties": {
          "name": "APOE"
        }
      }
    },
    {
      "data": {
        "properties": {
          "name": "APP"
        }
      }
    }
  ],
  "final_result": [
    {
      "data": {
        "properties": {
          "name": "APOE"
        }
      }
    },
    {
      "data": {
        "properties": {
          "name": "APP"
        }
      }
    }
  ]
}
```

### Output:
```
Based on the data, Alzheimer's Disease is associated with several genes, 
including APOE and APP. These genes have been found to play important roles 
in the development and progression of Alzheimer's Disease. APOE is particularly 
notable as a major genetic risk factor, while APP is involved in the formation 
of amyloid plaques, a hallmark of the disease.
```

## Chi tiết xử lý

### 1. Khởi tạo module

```python
answer_module = AnswerGenerator(llm_client=main_llm_client)
```

Module được khởi tạo một lần khi server start, sử dụng chung LLM client.

### 2. Main generation function

**Function**: `generate_final_answer()`

**Parameters**:
- `nlq`: Standalone question (từ QueryWriting)
- `context_store`: Toàn bộ context store từ SpokeExecutor

### 3. Validation

**Function**: `generate_final_answer()`

Kiểm tra xem có dữ liệu để trả lời không:

```python
if not context_store or not context_store.get("final_result"):
    if context_store:
        return "Based on the data, I followed the steps but could not find a final answer for your question."
    return "Based on the available data, I cannot find an answer to your question in the knowledge base."
```

**Các trường hợp**:
1. **Empty store**: Không có dữ liệu gì → "cannot find an answer"
2. **Empty final_result**: Có intermediate steps nhưng không có final result → "followed the steps but could not find"

### 4. Format context

**Function**: `generate_final_answer()`

Context store được convert sang JSON string:

```python
context_str = json.dumps(context_store, indent=2)
```

**Ví dụ**:
```json
{
  "diseases_list": [...],
  "genes_list": [...],
  "final_result": [...]
}
```

### 5. Build prompt

**Function**: `generate_final_answer()`

Prompt được tạo với các thành phần:

1. **Role**: Expert biomedical reasoning agent
2. **Task**: Answer question với step-by-step rationale
3. **Constraint**: Chỉ dùng dữ liệu trong context, không dùng external knowledge
4. **Context structure explanation**: Giải thích về các keys trong context store
5. **Instructions**: Hướng dẫn cách phân tích và trả lời

**Prompt template**:
```
You are an expert biomedical reasoning agent. Your task is to answer the user's 
question in clear, natural language, providing a step-by-step rationale.
You MUST base your answer ONLY on the structured JSON context provided below. 
Do not use any external knowledge.

The JSON context is a dictionary. Each key (e.g., "diseases_list", "final_result") 
represents the data found at a specific step of the query.
- The "final_result" key holds the primary list of items that answer the question.
- The *other keys* (e.g., "diseases_list") provide the intermediate *reasoning path* 
  or *evidence* that connects the query to the final answer.

User's Question:
"{nlq}"

Data Context from Knowledge Graph (all steps):
```json
{context_str}
```

Instructions:
1. Analyze the user's question: "{nlq}"
2. Look at the "final_result" key. This is the primary list of items to answer the question.
3. Look at the *other keys* in the JSON (e.g., "diseases_list", "side_effects_list") 
   to understand the *connection* or *reasoning* path.
4. Formulate a direct answer.
5. **Crucially, explain *how* you found the answer by referencing the intermediate steps.**

Example (for a query "What symptoms do diseases treated by Fulvestrant have?"):
"Based on the data, the drug Fulvestrant is found to treat diseases such as 
'Breast Cancer' and 'Ovarian Cancer'. These diseases, in turn, are associated 
with symptoms like 'Fatigue', 'Nausea', and 'Pain'."

If the "final_result" list is empty, state that no results were found after 
following the steps.
Do not mention the JSON file, keys (like "final_result"), or AI. Weave the 
reasoning into a natural language answer.
```

### 6. Gọi LLM

**Function**: `llm_client.generate_text()`

- **Model**: `gemini-2.5-pro` (model_main)
- **Max retries**: 2 (max_retries_main)
- **Output format**: Plain text (không phải JSON)
- **Rate limiting**: Có (vì dùng model_main)

**Code**:
```python
final_answer = await self.llm_client.generate_text(final_prompt)
```

### 7. Error handling

```python
try:
    final_answer = await self.llm_client.generate_text(final_prompt)
    return final_answer
except Exception as e:
    print(f"Error when generating final answer: {e}")
    return "An error occurred while trying to generate the final answer."
```

## Cấu trúc câu trả lời

### Format mong muốn

Câu trả lời nên có cấu trúc:

1. **Direct answer**: Trả lời trực tiếp câu hỏi
2. **Reasoning path**: Giải thích cách tìm ra câu trả lời
3. **Evidence**: Tham chiếu đến intermediate steps

### Ví dụ tốt

**Question**: "What symptoms do diseases treated by Aspirin have?"

**Answer**:
```
Based on the data, Aspirin is used to treat several conditions including 
Heart Disease, Stroke, and Arthritis. These conditions are associated with 
various symptoms:

- Heart Disease is linked to symptoms such as Chest Pain, Shortness of Breath, 
  and Fatigue.
- Stroke is associated with symptoms like Paralysis, Speech Difficulties, 
  and Vision Problems.
- Arthritis is connected to symptoms including Joint Pain, Stiffness, 
  and Swelling.

Therefore, the symptoms associated with diseases treated by Aspirin include 
a wide range of cardiovascular, neurological, and musculoskeletal symptoms.
```

**Giải thích**:
- ✅ Trả lời trực tiếp câu hỏi
- ✅ Giải thích reasoning path (Aspirin → Diseases → Symptoms)
- ✅ Tham chiếu đến intermediate steps (diseases_list)
- ✅ Không mention JSON keys hay AI

### Ví dụ không tốt

```
The final_result contains 15 symptoms. The diseases_list has 3 diseases. 
The answer is based on the JSON data provided.
```

**Vấn đề**:
- ❌ Mention JSON keys
- ❌ Không tự nhiên
- ❌ Không giải thích reasoning

## Xử lý các trường hợp đặc biệt

### 1. Empty final_result

**Prompt instruction**:
```
If the "final_result" list is empty, state that no results were found 
after following the steps.
```

**Ví dụ answer**:
```
Based on the data, I followed the steps to find symptoms of diseases 
treated by Aspirin. However, after querying the knowledge graph, 
no symptoms were found in the final results.
```

### 2. Large final_result

`final_result` đã được truncate về 15 items trong SpokeExecutor, nên LLM chỉ nhận được tối đa 15 items.

**Answer nên mention**:
```
Based on the data, I found several symptoms associated with diseases 
treated by Aspirin, including [list top items]. There may be additional 
symptoms not shown here.
```

### 3. Complex multi-hop query

**Question**: "What are the common symptoms of diseases treated by both Aspirin and Ibuprofen?"

**Context store**:
```json
{
  "diseases_A": [...],  // Diseases treated by Aspirin
  "diseases_B": [...],  // Diseases treated by Ibuprofen
  "common_diseases": [...],  // Intersection
  "symptoms": [...],  // Symptoms of common diseases
  "final_result": [...]
}
```

**Answer nên**:
- Mention cả 2 drugs
- Giải thích intersection step
- List symptoms từ final_result

## Lưu ý quan trọng

1. **Context preservation**: Toàn bộ context store được truyền vào, không chỉ final_result
2. **Reasoning explanation**: LLM được yêu cầu giải thích reasoning path
3. **Natural language**: Answer phải tự nhiên, không mention technical terms
4. **Evidence-based**: Chỉ dùng dữ liệu trong context, không hallucinate
5. **Performance**: Sử dụng model pro (chính xác) vì đây là bước quan trọng nhất

## Logging

Module log:
- "--- [Task 3] Synthesizing final answer... ---"
- Error messages nếu có

## Kết quả

Final answer được trả về và gửi về client qua WebSocket endpoint.

