# Planning - Tạo Execution Plan từ câu hỏi tự nhiên

## Vị trí trong flow

Bước thứ hai trong pipeline, sau Query Rewriting:

```
QueryWriting → SmartSearch (Planning) → SpokeExecutor → AnswerGenerator
```

## Mục đích

Phân tích câu hỏi tự nhiên (NLQ) và tạo ra một execution plan dưới dạng JSON, bao gồm:
- Các bước gọi SPOKE API
- Các phép toán logic (UNION, INTERSECTION)
- Thứ tự thực thi các bước

## File liên quan

- `modules/smart_search.py`: Module SmartSearch
- `modules/spoke_types.json`: Schema của SPOKE knowledge graph
- `modules/planner_prompt_v3.txt`: Prompt template cho LLM planner
- `modules/llm_client.py`: LLM client để gọi Gemini API

## Ví dụ

### Input:
**Standalone question**: "What genes are associated with Alzheimer's Disease?"

### Output:
```json
{
  "query_type": "one-hop",
  "thought": "This is a one-hop query. Plan: 1. Use /neighborhood to find 'Gene' neighbors of the 'Disease' node with the name 'Alzheimer's Disease' via 'ASSOCIATES_DaG'.",
  "entities": [
    {
      "name_in_query": "Alzheimer's Disease",
      "normalized_type": "Disease",
      "id_placeholder": "alz_entity"
    }
  ],
  "plan": [
    {
      "step": 1,
      "description": "Get genes associated with 'Alzheimer's Disease'",
      "api_call": "/api/v1/neighborhood/Disease/name/Alzheimer's Disease?edge_filters=ASSOCIATES_DaG&node_filters=Gene",
      "logic": null,
      "inputs": null,
      "store_as": "final_result"
    }
  ]
}
```

## Chi tiết xử lý

### 1. Khởi tạo module

```python
search_module = SmartSearch(
    llm_client=main_llm_client,
    schema_path="modules/spoke_types.json",
    planner_template_path="modules/planner_prompt_v3.txt"
)
```

Khi khởi tạo, module:
1. Load schema từ `spoke_types.json`
2. Process schema thành strings để inject vào prompt
3. Load planner prompt template

### 2. Load và process schema

**Function**: `_process_schema()`

Schema được xử lý thành các strings:

- **Node types**: Danh sách các loại node có thể query
  ```
  "Anatomy, CellLine, CellType, Chromosome, ClinicalLab, Compound, ..."
  ```

- **Edge types**: Danh sách các loại edge/relationship
  ```
  "ASSOCIATES_DaG, TREATS_CtD, CAUSES_DaG, ..."
  ```

- **Query fields**: Các field có thể dùng để query
  ```
  "Anatomy (query by 'name'), Cell Line (query by 'name'), ..."
  ```

- **Cutoffs**: Các filter parameters
  ```
  Node Cutoffs:
  - cutoff_CtD_phase (Clinical Trial Phase)
  - ...
  Edge Cutoffs:
  - cutoff_PiP_confidence (Protein-Protein Confidence)
  - ...
  ```

### 3. Tạo prompt cho LLM

**Function**: `get_execution_plan()`

Prompt được tạo bằng cách:
1. Format schema vào template (`planner_prompt_v3.txt`)
2. Thêm NLQ vào cuối prompt

**Prompt structure**:
```
You are an expert Biomedical Query Architect and Planner...

SPOKE API SCHEMA CONTEXT
- Valid Node Types: {INJECT_NODE_TYPES}
- Valid Searchable Fields: {INJECT_QUERY_FIELDS}
- Valid Edge Types: {INJECT_EDGE_TYPES}
- Valid Filters: {INJECT_CUTOFFS}

CORRECT SPOKE API CALL RULES
1️⃣ Anchor Query (Hop 1)
2️⃣ Expansion Query (Hop 2+)
3️⃣ Logic Steps (UNION/INTERSECTION)

OUTPUT FORMAT (STRICT JSON ONLY)
{...}

FEW-SHOT EXAMPLES
...

NLQ:
{standalone_question}
→
```

### 4. Gọi LLM

**Function**: `_call_llm_and_parse()`

- **Model**: `gemini-2.5-pro` (model_main)
- **Max retries**: 2 (max_retries_main)
- **Output format**: JSON (response_mime_type: "application/json")

**Code**:
```python
raw_output = await self.llm_client.generate(final_prompt)
```

### 5. Parse JSON response

**Function**: `_call_llm_and_parse()`

LLM có thể trả về JSON wrapped trong markdown code fences, nên cần clean:

```python
# Clean up potential markdown code fences
match = re.search(r'\{.*\}', raw_output, re.DOTALL)
if match:
    json_string = match.group(0)
else:
    json_string = raw_output

return json.loads(json_string)
```

### 6. Error handling

Nếu parse JSON fail:
```python
except json.JSONDecodeError as e:
    return {"error": "Failed to parse LLM output", "raw_output": raw_output}
```

## Cấu trúc Execution Plan

### Plan structure

```json
{
  "query_type": "one-hop" | "two-hop" | "multi-hop" | "complex",
  "thought": "Explanation of the plan",
  "entities": [
    {
      "name_in_query": "Entity name from question",
      "normalized_type": "Node type (e.g., Disease, Gene)",
      "id_placeholder": "Variable name"
    }
  ],
  "plan": [
    {
      "step": 1,
      "description": "Human-readable description",
      "api_call": "/api/v1/neighborhood/...",
      "logic": null | "UNION" | "INTERSECTION",
      "inputs": null | ["variable_name"],
      "store_as": "result_variable_name"
    }
  ]
}
```

### Các loại step

#### 1. Anchor Step (Bước đầu tiên)

```json
{
  "step": 1,
  "description": "Get genes associated with 'Alzheimer's Disease'",
  "api_call": "/api/v1/neighborhood/Disease/name/Alzheimer's Disease?edge_filters=ASSOCIATES_DaG&node_filters=Gene",
  "logic": null,
  "inputs": null,
  "store_as": "genes_list"
}
```

- `inputs`: null (không phụ thuộc bước trước)
- `api_call`: Full API path với entity name cụ thể

#### 2. Expansion Step (Bước mở rộng)

```json
{
  "step": 2,
  "description": "Get symptoms of each disease",
  "api_call": "/api/v1/neighborhood/{diseases_list.type}/name/{diseases_list.name}?edge_filters=HAS_SYMPTOM&node_filters=Symptom",
  "logic": null,
  "inputs": ["diseases_list"],
  "store_as": "symptoms_list"
}
```

- `inputs`: ["variable_name"] - sử dụng kết quả từ bước trước
- `api_call`: Template với `{variable.type}` và `{variable.name}`

#### 3. Logic Step (Phép toán logic)

```json
{
  "step": 3,
  "description": "Find common symptoms",
  "api_call": null,
  "logic": "INTERSECTION",
  "inputs": ["symptoms_list_A", "symptoms_list_B"],
  "store_as": "common_symptoms"
}
```

- `logic`: "UNION" (hợp) hoặc "INTERSECTION" (giao)
- `inputs`: 2 variables để thực hiện phép toán
- `api_call`: null

## Ví dụ các loại query

### One-hop query

**Question**: "What genes are associated with Alzheimer's Disease?"

**Plan**: 1 step - Anchor query

### Two-hop query

**Question**: "What symptoms do diseases treated by Aspirin have?"

**Plan**:
1. Get diseases treated by Aspirin
2. Get symptoms of each disease
3. Union all symptoms

### Complex query với logic

**Question**: "What are the common symptoms of diseases treated by both Aspirin and Ibuprofen?"

**Plan**:
1. Get diseases treated by Aspirin → `diseases_A`
2. Get diseases treated by Ibuprofen → `diseases_B`
3. Intersection → `common_diseases`
4. Get symptoms of common diseases → `symptoms`
5. Store as `final_result`

## Lưu ý quan trọng

1. **Schema validation**: LLM được cung cấp đầy đủ schema để đảm bảo chỉ tạo plan hợp lệ
2. **API endpoint**: Chỉ sử dụng `/api/v1/neighborhood`, không dùng `/search`
3. **Error handling**: Nếu LLM trả về invalid JSON, plan sẽ có field `error`
4. **Performance**: Sử dụng model pro (chính xác hơn) vì task này quan trọng và phức tạp

## Logging

Module log:
- "--- [Task 1] Calling Planner for: '{nlq}' ---"
- Error messages nếu có

## Kết quả

Execution plan được trả về và truyền vào bước tiếp theo: **SpokeExecutor**.

