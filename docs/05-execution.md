# Execution - Thực thi Plan và thu thập dữ liệu từ SPOKE API

## Vị trí trong flow

Bước thứ ba trong pipeline, sau Planning:

```
SmartSearch → SpokeExecutor → AnswerGenerator
```

## Mục đích

Thực thi execution plan bằng cách:
1. Gọi SPOKE API theo từng bước trong plan
2. Thực hiện các phép toán logic (UNION, INTERSECTION)
3. Lưu trữ kết quả vào context store
4. Áp dụng pruning nếu cần

## File liên quan

- `modules/spoke_executor.py`: Module SpokeExecutor
- `modules/llm_client.py`: LLM client cho pruning (optional)

## Ví dụ

### Input (Execution Plan):
```json
{
  "plan": [
    {
      "step": 1,
      "api_call": "/api/v1/neighborhood/Disease/name/Alzheimer's Disease?edge_filters=ASSOCIATES_DaG&node_filters=Gene",
      "store_as": "genes_list"
    },
    {
      "step": 2,
      "api_call": "/api/v1/neighborhood/{genes_list.type}/name/{genes_list.name}?edge_filters=ENCODES&node_filters=Protein",
      "inputs": ["genes_list"],
      "store_as": "proteins_list"
    }
  ]
}
```

### Output (Context Store):
```json
{
  "genes_list": [
    {
      "data": {
        "neo4j_type": "Gene",
        "properties": {
          "name": "APOE",
          "identifier": "ENSG00000130203"
        }
      }
    },
    ...
  ],
  "proteins_list": [
    {
      "data": {
        "neo4j_type": "Protein",
        "properties": {
          "name": "Apolipoprotein E",
          "identifier": "ENSP00000252486"
        }
      }
    },
    ...
  ],
  "final_result": [...]
}
```

## Chi tiết xử lý

### 1. Khởi tạo module

```python
executor = SpokeExecutor(
    base_url="https://spoke.rbvi.ucsf.edu",
    pruning_threshold=15,
    llm_client=main_llm_client  # Optional, để enable pruning
)
```

**Parameters**:
- `base_url`: Base URL của SPOKE API
- `pruning_threshold`: Số nodes tối đa trước khi trigger pruning (default: 15)
- `llm_client`: Optional, nếu có thì enable LLM pruning

### 2. Main execution function

**Function**: `execute_plan()`

Quy trình chính:

```
┌─────────────────┐
│ Initialize store│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Loop through    │
│ plan steps      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Execute step    │
│ - API call?     │
│ - Logic op?     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Check if needs  │
│ pruning         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Store result    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Return store    │
└─────────────────┘
```

### 3. Xử lý từng step

**Function**: `execute_plan()` - Loop through steps

```python
for i, step in enumerate(plan_steps):
    if step.get("api_call"):
        step_result = await self._execute_api_step(step, results_store)
    elif step.get("logic"):
        step_result = await self._execute_logic_step(step, results_store)
```

#### 3.1. API Step

**Function**: `_execute_api_step()`

Có 2 loại API call:

##### A. Anchor Call (Simple Neighborhood)

**Điều kiện**: `inputs` là null hoặc empty

**Function**: `_execute_simple_neighborhood_call()`

```python
url = f"{self.base_url}{api_call}"
response = self.session.get(url)
results = response.json()
```

**Xử lý kết quả**:
- Filter chỉ lấy neighbor nodes (không lấy anchor node)
- Điều kiện: `neo4j_root == 0` và không có `source`

```python
neighbor_nodes = []
for item in results:
    data = item.get("data")
    if data.get("neo4j_root") == 0 and "source" not in data:
        if data.get("neo4j_type") and data.get("properties", {}).get("name"):
            neighbor_nodes.append(item)
```

##### B. Looping Call (Expansion)

**Điều kiện**: `inputs` có giá trị

**Function**: `_execute_looping_neighborhood_call()`

```python
for node in input_nodes:
    node_type = node_data.get("neo4j_type")
    node_name = node_properties.get("name")
    
    # Construct API path
    base_path = f"/api/v1/neighborhood/{node_type}/name/{node_name}"
    url = f"{self.base_url}{base_path}"
    
    # Call API
    response = self.session.get(url, params=query_params)
    neighbors = response.json()
    
    # Filter và collect neighbors
    all_neighbor_nodes.extend(filtered_neighbors)
```

**Deduplication**: Sau khi loop xong, deduplicate bằng `identifier`:

```python
unique_nodes = {}
for node in all_neighbor_nodes:
    identifier = node['data']['properties']['identifier']
    if identifier not in unique_nodes:
        unique_nodes[identifier] = node
return list(unique_nodes.values())
```

#### 3.2. Logic Step

**Function**: `_execute_logic_step()`

Hỗ trợ 2 phép toán:

##### A. UNION (Hợp)

```python
if logic_op == "UNION":
    nodes_A_by_id.update(nodes_B_by_id)  # Merge B into A
    return list(nodes_A_by_id.values())
```

##### B. INTERSECTION (Giao)

```python
elif logic_op == "INTERSECTION":
    ids_A = nodes_A_by_id.keys()
    ids_B = nodes_B_by_id.keys()
    common_ids = ids_A & ids_B  # Set intersection
    return [nodes_A_by_id[node_id] for node_id in common_ids]
```

**Lưu ý**: Sử dụng `identifier` để so sánh nodes, không dùng name (vì có thể trùng tên).

### 4. Pruning Logic

**Function**: `execute_plan()` - Pruning check

Pruning được trigger khi:
1. Result là list
2. Số lượng nodes > `pruning_threshold` (15)
3. Đây là intermediate step (có step sau sử dụng kết quả này)
4. LLM client được cung cấp

```python
if (isinstance(step_result, list) and 
    len(step_result) > self.pruning_threshold):
    
    # Check if intermediate step
    is_intermediate = False
    if (i + 1) < len(plan_steps):
        for future_step in plan_steps[i+1:]:
            if step["store_as"] in future_step.get("inputs", []):
                is_intermediate = True
                break
    
    # Call LLM to prune
    if is_intermediate and self.llm_client:
        step_result = await self._prune_node_list(
            original_nlq,
            step_result,
            next_step_description
        )
```

Chi tiết pruning xem file `06-pruning.md`.

### 5. Store results

Sau mỗi step, kết quả được lưu vào `results_store`:

```python
if step_result is not None:
    results_store[step["store_as"]] = step_result
else:
    results_store[step["store_as"]] = []  # Empty list if no result
```

### 6. Final result truncation

Trước khi return, truncate `final_result` nếu quá lớn:

```python
final_results = results_store.get("final_result", [])
if isinstance(final_results, list) and len(final_results) > self.final_result_limit:
    results_store["final_result"] = final_results[:self.final_result_limit]
```

**final_result_limit**: 15 (hardcoded)

### 7. Return context store

```python
return results_store
```

Context store chứa tất cả intermediate results, không chỉ final_result. Điều này giúp Answer Generator có thể giải thích reasoning path.

## Cấu trúc Node

Mỗi node trong kết quả có cấu trúc:

```json
{
  "data": {
    "neo4j_type": "Gene",
    "neo4j_root": 0,
    "properties": {
      "name": "APOE",
      "identifier": "ENSG00000130203",
      ...
    }
  }
}
```

**Fields quan trọng**:
- `neo4j_type`: Loại node (Gene, Disease, Symptom, ...)
- `neo4j_root`: 0 = neighbor, 1 = anchor
- `properties.name`: Tên của node
- `properties.identifier`: Unique identifier

## Error handling

### API errors

```python
except requests.exceptions.RequestException as e:
    print(f"    ! API Error: {e}")
    return []  # Return empty list
```

### Invalid node structure

```python
except (KeyError, TypeError) as e:
    print(f"    ! Skipping node: invalid structure. {e}")
    continue
```

## Logging

Module log chi tiết:
- "--- [Executor] Executing {query_type} plan... ---"
- "[Step N] {description}"
- "-> Calling [NEIGHBORHOOD-ANCHOR]: GET {url}"
- "-> Calling [NEIGHBORHOOD-LOOP]: Executing {N} calls..."
- "-> Logic: Performing {UNION/INTERSECTION}..."
- "-> Stored {N} nodes in '{store_as}'"
- Pruning messages

## Lưu ý quan trọng

1. **Deduplication**: Tất cả kết quả được deduplicate bằng `identifier` để tránh duplicate nodes
2. **Neighbor filtering**: Chỉ lấy neighbor nodes, không lấy anchor node
3. **Pruning**: Chỉ prune intermediate steps, không prune final_result
4. **Error resilience**: Nếu một step fail, vẫn tiếp tục với step tiếp theo
5. **Context preservation**: Tất cả intermediate results được giữ lại để hỗ trợ answer generation

## Kết quả

Context store được trả về và truyền vào bước cuối cùng: **AnswerGenerator**.

