# Tài liệu Logic - Chat-server_Spoke

## Giới thiệu

Thư mục này chứa tài liệu chi tiết về logic xử lý của hệ thống Chat-server_Spoke, từ khi nhận câu hỏi cho đến khi trả về câu trả lời cuối cùng.

## Cấu trúc tài liệu

Tài liệu được chia thành các file theo flow xử lý:

1. **[01-overview.md](01-overview.md)**
   - Tổng quan về hệ thống
   - Kiến trúc tổng quan
   - Flow xử lý chính

2. **[02-websocket-endpoint.md](02-websocket-endpoint.md)**
   - WebSocket endpoint nhận request
   - Xử lý connection và message
   - Validation và error handling

3. **[03-query-rewriting.md](03-query-rewriting.md)**
   - Chuyển đổi câu hỏi follow-up thành standalone question
   - Sử dụng chat history để giải quyết đại từ và tham chiếu

4. **[04-planning.md](04-planning.md)**
   - Tạo execution plan từ câu hỏi tự nhiên
   - Phân tích schema SPOKE
   - Tạo các bước API calls và logic operations

5. **[05-execution.md](05-execution.md)**
   - Thực thi execution plan
   - Gọi SPOKE API để lấy dữ liệu
   - Thực hiện các phép toán logic (UNION, INTERSECTION)

6. **[06-pruning.md](06-pruning.md)**
   - Giảm số lượng nodes bằng LLM
   - Chọn top N nodes quan trọng nhất
   - Tối ưu hóa performance

7. **[07-answer-generation.md](07-answer-generation.md)**
   - Tạo câu trả lời tự nhiên từ dữ liệu
   - Giải thích reasoning path
   - Format và structure answer

8. **[08-llm-client.md](08-llm-client.md)**
   - Quản lý kết nối với Gemini API
   - Rate limiting (proactive và reactive)
   - Retry logic và error handling

## Flow tổng quan

```
┌─────────────────────────────────────────────────────────────┐
│                    WebSocket Endpoint                       │
│                  (02-websocket-endpoint.md)                 │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Query Rewriting                          │
│                  (03-query-rewriting.md)                    │
│  Input: question + history                                  │
│  Output: standalone question                                 │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                        Planning                              │
│                      (04-planning.md)                        │
│  Input: standalone question                                  │
│  Output: execution plan (JSON)                               │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                       Execution                              │
│                     (05-execution.md)                        │
│  Input: execution plan                                       │
│  Output: context store (data)                               │
│                                                              │
│  ┌────────────────────────────────────────┐                │
│  │         Pruning (optional)              │                │
│  │        (06-pruning.md)                  │                │
│  └────────────────────────────────────────┘                │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Answer Generation                           │
│                (07-answer-generation.md)                     │
│  Input: context store + question                             │
│  Output: natural language answer                             │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    WebSocket Response                        │
│                  (02-websocket-endpoint.md)                  │
└─────────────────────────────────────────────────────────────┘

                    ┌─────────────────┐
                    │   LLM Client    │
                    │ (08-llm-client) │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
   QueryWriting        SmartSearch         AnswerGenerator
   (uses flash)        (uses pro)          (uses pro)
```

## Cách đọc tài liệu

### Cho người mới bắt đầu

1. Bắt đầu với **[01-overview.md](01-overview.md)** để hiểu tổng quan
2. Đọc theo thứ tự từ 02 → 08 để theo dõi flow xử lý
3. Mỗi file có ví dụ cụ thể và code snippets

### Cho developer

1. Đọc **[01-overview.md](01-overview.md)** để nắm kiến trúc
2. Đọc file tương ứng với module bạn đang làm việc
3. Tham khảo **[08-llm-client.md](08-llm-client.md)** để hiểu về rate limiting và retry logic

### Cho người debug

1. Xác định vấn đề xảy ra ở bước nào trong flow
2. Đọc file tương ứng để hiểu logic xử lý
3. Kiểm tra error handling và logging trong file đó

## Các khái niệm quan trọng

### Execution Plan

JSON structure mô tả các bước để query SPOKE knowledge graph:
- API calls
- Logic operations (UNION, INTERSECTION)
- Thứ tự thực thi

### Context Store

Dictionary chứa tất cả intermediate results:
- Key: tên biến (ví dụ: "diseases_list", "final_result")
- Value: list of nodes hoặc kết quả khác

### Pruning

Quá trình giảm số lượng nodes bằng LLM để tối ưu performance:
- Chỉ áp dụng cho intermediate steps
- Sử dụng LLM để chọn top N nodes quan trọng nhất

### Rate Limiting

Quản lý số lượng requests đến Gemini API:
- Proactive: Chờ trước khi gọi
- Reactive: Retry sau khi gặp lỗi

## Liên kết với code

Mỗi file tài liệu có section "File liên quan" chỉ rõ:
- File Python tương ứng
- Functions quan trọng
- Code locations

## Cập nhật tài liệu

Khi thay đổi logic:
1. Cập nhật file tài liệu tương ứng
2. Cập nhật flow diagram nếu cần
3. Thêm ví dụ mới nếu có use case mới

## Hỗ trợ

Nếu có câu hỏi về logic:
1. Đọc file tài liệu tương ứng
2. Kiểm tra code trong file Python
3. Xem logging để debug

