# API Documentation

## Mục lục
1. [Authentication](#authentication)
2. [User APIs](#user-apis)
3. [Chat Session APIs](#chat-session-apis)
4. [Message APIs](#message-apis)
5. [WebSocket](#websocket)

---

## Authentication

Tất cả các API yêu cầu authentication (trừ login, sign-up, restore-pass) cần gửi JWT token trong header:

```
Authorization: <token>
```

Token được trả về sau khi login hoặc sign-up thành công.

---

## User APIs

### 1. Đăng nhập

**Mô tả:** Đăng nhập vào hệ thống bằng email và password.

**Endpoint:** `POST /users/login`

**Method:** `POST`

**Authentication:** Không cần

**Payload:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "user": {
    "_id": "user_id",
    "username": "username",
    "email": "user@example.com"
  },
  "token": "jwt_token_string"
}
```

**Status Code:** `200 OK`

---

### 2. Đăng ký

**Mô tả:** Tạo tài khoản mới trong hệ thống.

**Endpoint:** `POST /users/sign-up`

**Method:** `POST`

**Authentication:** Không cần

**Payload:**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "username": "username"
}
```

**Response:**
```json
{
  "user": {
    "_id": "user_id",
    "username": "username",
    "email": "user@example.com",
    "createdAt": "2024-01-01T00:00:00.000Z",
    "updatedAt": "2024-01-01T00:00:00.000Z"
  },
  "token": "jwt_token_string"
}
```

**Status Code:** `201 Created`

---

### 3. Lấy thông tin profile

**Mô tả:** Lấy thông tin profile của user hiện tại.

**Endpoint:** `GET /users/get-profile`

**Method:** `GET`

**Authentication:** Cần (JWT token)

**Payload:** Không có

**Response:**
```json
{
  "user": {
    "_id": "user_id",
    "username": "username",
    "email": "user@example.com",
    "createdAt": "2024-01-01T00:00:00.000Z",
    "updatedAt": "2024-01-01T00:00:00.000Z"
  }
}
```

**Status Code:** `200 OK`

---

### 4. Cập nhật username

**Mô tả:** Thay đổi username của user hiện tại.

**Endpoint:** `PATCH /users/username`

**Method:** `PATCH`

**Authentication:** Cần (JWT token)

**Payload:**
```json
{
  "newUsername": "new_username"
}
```

**Response:**
```json
{
  "user": {
    "_id": "user_id",
    "username": "new_username",
    "email": "user@example.com",
    "updatedAt": "2024-01-01T00:00:00.000Z"
  }
}
```

**Status Code:** `200 OK`

---

### 5. Đổi password

**Mô tả:** Thay đổi password của user hiện tại.

**Endpoint:** `PATCH /users/password`

**Method:** `PATCH`

**Authentication:** Cần (JWT token)

**Payload:**
```json
{
  "oldPassword": "old_password",
  "newPassword": "new_password"
}
```

**Response:**
```json
{
  "message": "Password changed successfully"
}
```

**Status Code:** `200 OK`

---

### 6. Khôi phục password

**Mô tả:** Khôi phục password (đang trong quá trình phát triển).

**Endpoint:** `POST /users/restore-pass`

**Method:** `POST`

**Authentication:** Không cần

**Payload:**
```json
{
  "email": "user@example.com"
}
```

**Response:** Đang trong quá trình phát triển

**Status Code:** `200 OK`

---

## Chat Session APIs

### 1. Lấy danh sách chat session

**Mô tả:** Lấy danh sách các chat session của user hiện tại với phân trang.

**Endpoint:** `GET /chat-sessions/get-by-user`

**Method:** `GET`

**Authentication:** Cần (JWT token)

**Query Parameters:**
- `page` (optional): Số trang (mặc định: 1)
- `limit` (optional): Số lượng items mỗi trang (mặc định: 20)

**Payload:** Không có

**Response:**
```json
{
  "chatSessions": [
    {
      "_id": "session_id",
      "userId": "user_id",
      "title": "Chat Title",
      "isDeleted": false,
      "createdAt": "2024-01-01T00:00:00.000Z",
      "updatedAt": "2024-01-01T00:00:00.000Z"
    }
  ],
  "metadata": {
    "currentPage": 1,
    "nextPage": 2,
    "prevPage": null,
    "totalPages": 5,
    "totalItems": 100,
    "itemPerPage": 20,
    "itemsRemain": 80
  }
}
```

**Status Code:** `200 OK`

---

### 2. Đổi tên chat session

**Mô tả:** Đổi tên của một chat session.

**Endpoint:** `PATCH /chat-sessions/:id/name`

**Method:** `PATCH`

**Authentication:** Cần (JWT token)

**Path Parameters:**
- `id`: ID của chat session

**Payload:**
```json
{
  "newTitle": "New Chat Title"
}
```

**Response:**
```json
{
  "chatSession": {
    "_id": "session_id",
    "userId": "user_id",
    "title": "New Chat Title",
    "isDeleted": false,
    "updatedAt": "2024-01-01T00:00:00.000Z"
  }
}
```

**Status Code:** `200 OK`

---

### 3. Xóa mềm chat session

**Mô tả:** Xóa mềm (soft delete) một chat session - đánh dấu là đã xóa nhưng không xóa khỏi database.

**Endpoint:** `PATCH /chat-sessions/:id/soft-delete`

**Method:** `PATCH`

**Authentication:** Cần (JWT token)

**Path Parameters:**
- `id`: ID của chat session

**Payload:** Không có

**Response:**
```json
{
  "message": "chat session soft deleted successfully"
}
```

**Status Code:** `200 OK`

---

### 4. Xóa chat session

**Mô tả:** Xóa vĩnh viễn một chat session khỏi database.

**Endpoint:** `DELETE /chat-sessions/:id`

**Method:** `DELETE`

**Authentication:** Cần (JWT token)

**Path Parameters:**
- `id`: ID của chat session

**Payload:** Không có

**Response:**
```json
{
  "message": "chat session deleted successfully"
}
```

**Status Code:** `200 OK`

---

## Message APIs

### 1. Lấy danh sách messages theo session

**Mô tả:** Lấy danh sách các messages trong một chat session với phân trang.

**Endpoint:** `GET /messages/session/:id/get-messages`

**Method:** `GET`

**Authentication:** Cần (JWT token)

**Path Parameters:**
- `id`: ID của chat session

**Query Parameters:**
- `page` (optional): Số trang (mặc định: 1)
- `limit` (optional): Số lượng items mỗi trang (mặc định: 20, tối đa: 100)

**Payload:** Không có

**Response:**
```json
{
  "chatMessages": [
    {
      "_id": "message_id",
      "chatSessionId": "session_id",
      "role": "user",
      "content": "Câu hỏi của user",
      "createdAt": "2024-01-01T00:00:00.000Z",
      "updatedAt": "2024-01-01T00:00:00.000Z"
    },
    {
      "_id": "message_id_2",
      "chatSessionId": "session_id",
      "role": "bot",
      "content": "Câu trả lời của bot",
      "createdAt": "2024-01-01T00:00:01.000Z",
      "updatedAt": "2024-01-01T00:00:01.000Z"
    }
  ],
  "metadata": {
    "currentPage": 1,
    "nextPage": 2,
    "prevPage": null,
    "totalPages": 5,
    "totalItems": 100,
    "itemPerPage": 20,
    "itemsRemain": 80
  }
}
```

**Status Code:** `200 OK`

**Lưu ý:** 
- Messages được sắp xếp theo thời gian tạo (từ cũ đến mới)
- `role` có thể là `"user"` hoặc `"bot"`

---

## WebSocket

### Kết nối

**Mô tả:** Kết nối WebSocket để gửi/nhận messages real-time với AI chatbot.

**Connection URL:** `ws://<host>:<port>` hoặc `wss://<host>:<port>` (nếu có SSL)

**Authentication:** 
Khi kết nối, cần gửi JWT token trong handshake:
```javascript
const socket = io(url, {
  auth: {
    token: "jwt_token_string"
  }
})
```

---

### Events

#### 1. Client gửi: `ask-question`

**Mô tả:** Gửi câu hỏi đến AI chatbot.

**Event Name:** `ask-question`

**Payload:**
```json
{
  "question": "Câu hỏi của bạn",
  "chatSessionId": "session_id" // optional, nếu không có sẽ tạo session mới
}
```

**Ví dụ:**
```javascript
socket.emit("ask-question", {
  question: "Xin chào, bạn là ai?",
  chatSessionId: "optional_session_id"
})
```

---

#### 2. Server gửi: `server-ack`

**Mô tả:** Server xác nhận đã nhận được câu hỏi và đang xử lý.

**Event Name:** `server-ack`

**Payload:**
```json
{
  "status": "processing"
}
```

**Ví dụ:**
```javascript
socket.on("server-ack", (data) => {
  console.log("Server đang xử lý:", data.status)
})
```

---

#### 3. Server gửi: `receive-answer`

**Mô tả:** Server gửi câu trả lời từ AI chatbot.

**Event Name:** `receive-answer`

**Payload:**
```json
{
  "answer": "Câu trả lời từ AI",
  "chatSessionId": "session_id",
  "messages": [
    {
      "_id": "message_id",
      "chatSessionId": "session_id",
      "role": "user",
      "content": "Câu hỏi của user",
      "createdAt": "2024-01-01T00:00:00.000Z",
      "updatedAt": "2024-01-01T00:00:00.000Z"
    },
    {
      "_id": "message_id_2",
      "chatSessionId": "session_id",
      "role": "bot",
      "content": "Câu trả lời của bot",
      "createdAt": "2024-01-01T00:00:01.000Z",
      "updatedAt": "2024-01-01T00:00:01.000Z"
    }
  ]
}
```

**Ví dụ:**
```javascript
socket.on("receive-answer", (data) => {
  console.log("Câu trả lời:", data.answer)
  console.log("Session ID:", data.chatSessionId)
  console.log("Messages:", data.messages)
})
```

---

#### 4. Server gửi: `error-message`

**Mô tả:** Server gửi thông báo lỗi khi có lỗi xảy ra.

**Event Name:** `error-message`

**Payload:**
```json
{
  "message": "Mô tả lỗi"
}
```

**Ví dụ:**
```javascript
socket.on("error-message", (data) => {
  console.error("Lỗi:", data.message)
})
```

---

#### 5. Client/Server: `disconnect`

**Mô tả:** Event được emit khi client hoặc server ngắt kết nối.

**Event Name:** `disconnect`

**Payload:** Không có

**Ví dụ:**
```javascript
socket.on("disconnect", () => {
  console.log("Đã ngắt kết nối")
})
```

---

### Ví dụ sử dụng WebSocket (JavaScript)

```javascript
import io from 'socket.io-client'

// Kết nối với token
const socket = io('http://localhost:3000', {
  auth: {
    token: 'your_jwt_token_here'
  }
})

// Lắng nghe khi kết nối thành công
socket.on('connect', () => {
  console.log('Đã kết nối WebSocket')
  
  // Gửi câu hỏi
  socket.emit('ask-question', {
    question: 'Xin chào, bạn là ai?',
    chatSessionId: 'optional_session_id'
  })
})

// Lắng nghe xác nhận từ server
socket.on('server-ack', (data) => {
  console.log('Server đang xử lý:', data.status)
})

// Lắng nghe câu trả lời
socket.on('receive-answer', (data) => {
  console.log('Câu trả lời:', data.answer)
  console.log('Session ID:', data.chatSessionId)
  console.log('Messages:', data.messages)
})

// Lắng nghe lỗi
socket.on('error-message', (data) => {
  console.error('Lỗi:', data.message)
})

// Lắng nghe khi ngắt kết nối
socket.on('disconnect', () => {
  console.log('Đã ngắt kết nối')
})
```

---

## Error Handling

Tất cả các API có thể trả về các lỗi sau:

### 401 Unauthorized
```json
{
  "error": "Authorization token missing"
}
```
hoặc
```json
{
  "error": "Request not authorized"
}
```

### 400 Bad Request
```json
{
  "error": "Mô tả lỗi",
  "code": "ERROR_CODE"
}
```

### 404 Not Found
```json
{
  "error": "Mô tả lỗi",
  "code": "ERROR_CODE"
}
```

### 500 Internal Server Error
```json
{
  "error": "Mô tả lỗi",
  "code": "ERROR_CODE"
}
```

---

## Lưu ý

1. Tất cả các API yêu cầu authentication (trừ login, sign-up, restore-pass) cần gửi JWT token trong header `Authorization`
2. WebSocket cần authenticate bằng cách gửi token trong handshake auth
3. Tất cả các ID sử dụng MongoDB ObjectId format
4. Timestamps sử dụng ISO 8601 format
5. Phân trang: `page` bắt đầu từ 1, `limit` có giới hạn tối đa tùy theo API

