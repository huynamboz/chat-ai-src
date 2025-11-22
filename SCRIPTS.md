# Docker Management Scripts

Các script tiện ích để quản lý Docker container cho Chat-server_Spoke.

## Các script có sẵn

### 1. `restart.sh` - Restart container

Restart container với code mới nhất:
- Stop và remove container cũ
- Build lại Docker image
- Chạy container mới

**Usage:**
```bash
./restart.sh
```

**Khi nào dùng:**
- Sau khi pull code mới
- Sau khi thay đổi code
- Khi cần rebuild image

### 2. `stop.sh` - Stop container

Dừng container đang chạy.

**Usage:**
```bash
./stop.sh
```

### 3. `logs.sh` - Xem logs

Xem logs của container.

**Usage:**
```bash
# Xem real-time logs (nhấn Ctrl+C để thoát)
./logs.sh

# Xem N dòng cuối cùng
./logs.sh 50
```

### 4. `status.sh` - Kiểm tra status

Kiểm tra trạng thái container và xem logs gần nhất.

**Usage:**
```bash
./status.sh
```

## Ví dụ workflow

### Lần đầu tiên setup:
```bash
# 1. Đảm bảo có file .env
ls .env

# 2. Restart container (sẽ build và chạy)
./restart.sh
```

### Sau khi pull code mới:
```bash
# 1. Pull code
git pull

# 2. Restart với code mới
./restart.sh
```

### Kiểm tra và debug:
```bash
# Kiểm tra status
./status.sh

# Xem logs real-time
./logs.sh

# Xem 50 dòng logs cuối
./logs.sh 50
```

### Dừng server:
```bash
./stop.sh
```

## Lưu ý

- Tất cả script đều cần quyền execute: `chmod +x script.sh`
- Script `restart.sh` yêu cầu file `.env` tồn tại
- Port mặc định: `8001`
- Container name: `chatai-spoke`

## Troubleshooting

### Script không chạy được:
```bash
chmod +x restart.sh stop.sh logs.sh status.sh
```

### Container không start:
```bash
# Kiểm tra logs
./logs.sh 50

# Kiểm tra .env file
cat .env
```

### Port đã được sử dụng:
```bash
# Kiểm tra port
lsof -i :8001

# Hoặc dừng container cũ
./stop.sh
```

