# Hướng dẫn Setup

## Vấn đề: Database connection failed

Lỗi `MongooseServerSelectionError: connect ECONNREFUSED 127.0.0.1:27017` xảy ra khi MongoDB chưa được khởi động.

## Giải pháp

### Cách 1: Chạy MongoDB với Docker Compose (Khuyến nghị)

1. Tạo file `.env` trong thư mục gốc với nội dung:
```env
PORT=3000
HOST=http://localhost
DB_URI=mongodb://mongodb:27017/chatdb
JWT_SECRET=your_jwt_secret_key_here
SPOKE_AGENT_URL=
```

2. Chạy tất cả services với docker-compose:
```bash
docker-compose up -d
```

3. Kiểm tra logs:
```bash
docker-compose logs -f chat-server
```

### Cách 2: Chạy MongoDB local

1. Cài đặt MongoDB trên máy local:
   - macOS: `brew install mongodb-community`
   - Ubuntu: `sudo apt-get install mongodb`
   - Windows: Tải từ [MongoDB website](https://www.mongodb.com/try/download/community)

2. Khởi động MongoDB:
   ```bash
   # macOS với Homebrew
   brew services start mongodb-community
   
   # Hoặc chạy trực tiếp
   mongod --dbpath /path/to/data/db
   ```

3. Tạo file `.env` với nội dung:
```env
PORT=3000
HOST=http://localhost
DB_URI=mongodb://localhost:27017/chatdb
JWT_SECRET=your_jwt_secret_key_here
SPOKE_AGENT_URL=
```

4. Chạy ứng dụng:
```bash
npm start
```

### Cách 3: Chỉ chạy MongoDB với Docker

1. Chạy MongoDB container:
```bash
docker run -d \
  --name chat-mongodb \
  -p 27017:27017 \
  -v mongodb_data:/data/db \
  mongo:7.0
```

2. Tạo file `.env` với:
```env
PORT=3000
HOST=http://localhost
DB_URI=mongodb://localhost:27017/chatdb
JWT_SECRET=your_jwt_secret_key_here
SPOKE_AGENT_URL=
```

3. Chạy ứng dụng:
```bash
npm start
```

## Kiểm tra kết nối

Sau khi khởi động MongoDB, bạn sẽ thấy log:
```
Database connected successfully!
```

Nếu vẫn gặp lỗi, kiểm tra:
- MongoDB đã chạy chưa: `docker ps` hoặc `ps aux | grep mongod`
- Port 27017 có bị chiếm không: `lsof -i :27017`
- DB_URI trong file `.env` có đúng không



