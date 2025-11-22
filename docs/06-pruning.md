# Pruning - Giảm số lượng nodes bằng LLM

## Vị trí trong flow

Pruning được thực hiện trong quá trình Execution, khi một step trả về quá nhiều nodes:

```
SpokeExecutor.execute_plan()
  ├─ Execute step → Get large list
  ├─ Check if needs pruning
  ├─ [PRUNING] Call LLM to filter nodes ← Bạn đang ở đây
  └─ Store pruned result
```

## Mục đích

Khi một API call trả về quá nhiều nodes (ví dụ: 100+ genes), việc tiếp tục expand từ tất cả nodes này sẽ:
- Tốn thời gian (nhiều API calls)
- Tốn tài nguyên
- Có thể không cần thiết (nhiều nodes không liên quan)

Pruning sử dụng LLM để chọn ra top N nodes quan trọng nhất dựa trên:
- Original question
- Next step description
- Node names

## File liên quan

- `modules/spoke_executor.py`: Function `_prune_node_list()`
- `modules/llm_client.py`: LLM client để gọi Gemini API

## Điều kiện trigger pruning

Pruning được trigger khi **TẤT CẢ** các điều kiện sau đều đúng:

1. ✅ Result là một list
2. ✅ Số lượng nodes > `pruning_threshold` (default: 15)
3. ✅ Đây là **intermediate step** (có step sau sử dụng kết quả này)
4. ✅ LLM client được cung cấp (`self.llm_client` không None)

**Code**:
```python
if (isinstance(step_result, list) and 
    len(step_result) > self.pruning_threshold):
    
    is_intermediate = False
    if (i + 1) < len(plan_steps):
        for future_step in plan_steps[i+1:]:
            if step["store_as"] in future_step.get("inputs", []):
                is_intermediate = True
                break
    
    if is_intermediate and self.llm_client:
        step_result = await self._prune_node_list(...)
```

## Ví dụ

### Trước pruning:
- **Step 1**: Get diseases treated by Aspirin → 50 diseases
- **Step 2**: Get symptoms of each disease (sẽ gọi 50 API calls!)

### Sau pruning:
- **Step 1**: Get diseases treated by Aspirin → 50 diseases
- **[PRUNING]**: LLM chọn top 15 diseases quan trọng nhất
- **Step 2**: Get symptoms of 15 diseases (chỉ cần 15 API calls)

## Chi tiết xử lý

### 1. Extract node names

**Function**: `_prune_node_list()`

Đầu tiên, extract tên của tất cả nodes:

```python
node_names = []
for node in node_list:
    try:
        name = node['data']['properties']['name']
        node_names.append(name)
    except (KeyError, TypeError):
        continue

unique_names = sorted(list(set(node_names)))
```

**Ví dụ**:
```python
unique_names = [
    "Alzheimer's Disease",
    "Breast Cancer",
    "Diabetes Type 2",
    ...
]
```

### 2. Build pruning prompt

**Function**: `_prune_node_list()`

Prompt được tạo với các thông tin:

- **Original question**: Câu hỏi gốc của user
- **Next step description**: Mô tả bước tiếp theo sẽ làm gì
- **Node list**: Danh sách tất cả node names
- **Threshold**: Số lượng nodes muốn giữ lại

**Prompt template**:
```
You are an expert biomedical reasoning agent. Your task is to prune a large list 
of nodes to make a graph query more efficient.

The user's original question is:
"{nlq}"

I have just found {N} potential nodes. My *next* step in the plan is to:
"{next_step_desc}"

This list is too large to process. Please select the **Top {threshold}** most 
relevant, common, or severe nodes from the following list that I should investigate 
further for my *next* step.

Full list of {N} node names:
{json.dumps(unique_names)}

You MUST respond with a JSON object containing a *single key* "selected_names", 
which is a list of the exact string names you selected.
Example: {"selected_names": ["Name 1", "Name 2", "Name 3"]}
```

**Ví dụ prompt**:
```
The user's original question is:
"What symptoms do diseases treated by Aspirin have?"

I have just found 50 potential nodes. My *next* step in the plan is to:
"Get symptoms of each disease"

Please select the **Top 15** most relevant, common, or severe nodes...
```

### 3. Call LLM

**Function**: `llm_client.filter_nodes()`

- **Model**: `gemini-2.0-flash` (model_filter)
- **Max retries**: 10 (max_retries_sub)
- **Output format**: JSON

**Code**:
```python
raw_json_string = await self.llm_client.filter_nodes(pruning_prompt)
parsed_response = json.loads(raw_json_string)
selected_names = parsed_response.get("selected_names")
```

### 4. Filter original node list

Sau khi LLM trả về selected names, filter original node list:

```python
selected_name_set = set(selected_names)
pruned_list = []

for node in node_list:
    try:
        name = node['data']['properties']['name']
        if name in selected_name_set:
            pruned_list.append(node)
    except (KeyError, TypeError):
        continue
```

### 5. Deduplicate

Cuối cùng, deduplicate bằng `identifier`:

```python
unique_nodes = {}
for node in pruned_list:
    try:
        identifier = node['data']['properties']['identifier']
        if identifier not in unique_nodes:
            unique_nodes[identifier] = node
    except (KeyError, TypeError):
        continue

final_pruned_list = list(unique_nodes.values())
```

## Error handling

### 1. No names found

```python
if not unique_names:
    print("    ! [PRUNING] No names found to prune. Returning original list.")
    return node_list
```

### 2. Invalid LLM response

```python
if not selected_names or not isinstance(selected_names, list):
    print(f"    ! [PRUNING] LLM response invalid. Returning original list.")
    return node_list
```

### 3. Exception during pruning

```python
except Exception as e:
    print(f"    ! [PRUNING] Error during LLM pruning call: {e}. Returning original list.")
    return node_list
```

**Lưu ý**: Nếu pruning fail, hệ thống vẫn tiếp tục với original list (fail-safe).

## Ví dụ chi tiết

### Scenario

**Question**: "What symptoms do diseases treated by Aspirin have?"

**Plan**:
1. Get diseases treated by Aspirin → `diseases_list` (50 diseases)
2. Get symptoms of each disease → `symptoms_list`

### Step 1 execution

```python
# API call returns 50 diseases
diseases_list = [
    {"data": {"properties": {"name": "Alzheimer's Disease"}}},
    {"data": {"properties": {"name": "Breast Cancer"}}},
    {"data": {"properties": {"name": "Rare Disease X"}}},
    ...  # 47 more diseases
]
```

### Pruning check

```python
# Check: len(diseases_list) = 50 > 15? ✅
# Check: Is intermediate? ✅ (Step 2 uses diseases_list)
# Check: LLM client available? ✅
# → Trigger pruning!
```

### LLM pruning

**Input to LLM**:
- Original question: "What symptoms do diseases treated by Aspirin have?"
- Next step: "Get symptoms of each disease"
- Node list: 50 disease names
- Request: Select top 15 most relevant

**LLM output**:
```json
{
  "selected_names": [
    "Alzheimer's Disease",
    "Breast Cancer",
    "Diabetes Type 2",
    "Heart Disease",
    "Stroke",
    ...  // 10 more common/severe diseases
  ]
}
```

### Filter nodes

```python
# Filter original list to only include selected names
pruned_list = [
    {"data": {"properties": {"name": "Alzheimer's Disease"}}},
    {"data": {"properties": {"name": "Breast Cancer"}}},
    ...  // Only 15 diseases
]
```

### Result

- **Before**: 50 diseases → Step 2 sẽ gọi 50 API calls
- **After**: 15 diseases → Step 2 chỉ cần 15 API calls
- **Savings**: 70% reduction in API calls

## Lưu ý quan trọng

1. **Chỉ prune intermediate steps**: Không bao giờ prune `final_result`
2. **Fail-safe**: Nếu pruning fail, vẫn tiếp tục với original list
3. **Deduplication**: Luôn deduplicate sau khi filter
4. **Performance**: Sử dụng model flash (nhanh) vì task này đơn giản
5. **Context-aware**: LLM được cung cấp original question và next step để đưa ra quyết định tốt

## Logging

Module log chi tiết:
- "! Pruning '{store_as}': list is large ({N} nodes)."
- "-> [PRUNING] Calling LLM to prune {N} nodes for step: '{next_step_desc}'"
- "-> [PRUNING] LLM raw response: {response}..."
- "-> [PRUNING] Successful. List reduced from {N} to {M} nodes."
- Error messages nếu có

## Kết quả

Pruned list được trả về và tiếp tục với execution flow bình thường.

