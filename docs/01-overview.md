# Tổng quan hệ thống

## Mục đích

Hệ thống Chat-server_Spoke là một AI server xử lý câu hỏi y sinh học bằng cách:
1. Nhận câu hỏi tự nhiên từ người dùng qua WebSocket
2. Chuyển đổi câu hỏi thành execution plan để query SPOKE knowledge graph
3. Thực thi plan và thu thập dữ liệu từ SPOKE API
4. Tạo câu trả lời tự nhiên dựa trên dữ liệu đã thu thập

## Kiến trúc tổng quan

```
┌─────────────┐
│   Client    │
│  (WebSocket)│
└──────┬──────┘
       │
       │ question + history
       ▼
┌─────────────────────────────────────────────────────────┐
│              server_ai_main.py                           │
│  ┌───────────────────────────────────────────────────┐  │
│  │  WebSocket Endpoint: /ws/query                    │  │
│  └───────────────────────────────────────────────────┘  │
│                          │                                │
│                          ▼                                │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Pipeline: run_full_pipeline()                    │  │
│  │  1. QueryWriting → Rewrite question              │  │
│  │  2. SmartSearch → Generate execution plan         │  │
│  │  3. SpokeExecutor → Execute plan & fetch data    │  │
│  │  4. AnswerGenerator → Generate final answer      │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Gemini    │    │   SPOKE     │    │   Gemini    │
│   LLM API   │    │   API       │    │   LLM API   │
└─────────────┘    └─────────────┘    └─────────────┘
```

## Flow xử lý chính

1. **WebSocket Connection** (`02-websocket-endpoint.md`)
   - Nhận kết nối WebSocket từ client
   - Nhận JSON chứa `question` và `history`
   - Gọi pipeline xử lý

2. **Query Rewriting** (`03-query-rewriting.md`)
   - Chuyển đổi câu hỏi follow-up thành standalone question
   - Sử dụng chat history để giải quyết đại từ và tham chiếu

3. **Planning** (`04-planning.md`)
   - Phân tích câu hỏi và tạo execution plan
   - Plan bao gồm các bước API calls và logic operations

4. **Execution** (`05-execution.md`)
   - Thực thi từng bước trong plan
   - Gọi SPOKE API để lấy dữ liệu
   - Thực hiện các phép toán logic (UNION, INTERSECTION)

5. **Pruning** (`06-pruning.md`)
   - Tự động giảm số lượng nodes khi kết quả quá lớn
   - Sử dụng LLM để chọn nodes quan trọng nhất

6. **Answer Generation** (`07-answer-generation.md`)
   - Tổng hợp dữ liệu đã thu thập
   - Tạo câu trả lời tự nhiên với giải thích

7. **LLM Client** (`08-llm-client.md`)
   - Quản lý kết nối với Gemini API
   - Xử lý rate limiting và retry logic

## Các module chính

- **server_ai_main.py**: Entry point, WebSocket handler, pipeline orchestrator
- **modules/query_writing.py**: Query rewriting module
- **modules/smart_search.py**: Planning module
- **modules/spoke_executor.py**: Execution và pruning module
- **modules/generate_answer.py**: Answer generation module
- **modules/llm_client.py**: LLM client với rate limiting

## Dữ liệu đầu vào

- **question**: Câu hỏi của người dùng (string)
- **history**: Lịch sử chat (list of messages với `role` và `content`)

## Dữ liệu đầu ra

- **answer**: Câu trả lời tự nhiên (string)
- Hoặc **error**: Thông báo lỗi nếu có vấn đề

