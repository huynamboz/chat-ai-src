# Scripts Hữu Ích

## 1. `restart-services.sh` - Restart đầy đủ với kiểm tra

Script này sẽ:
- Kết nối `chatai-spoke` vào network `chat-be_chat-network`
- Restart `chat-server`
- Kiểm tra kết nối
- Hiển thị logs

**Sử dụng:**
```bash
./restart-services.sh
```

**Khi nào dùng:**
- Sau khi restart container `chatai-spoke`
- Khi gặp lỗi kết nối giữa chat-server và chatai-spoke
- Khi muốn kiểm tra đầy đủ trạng thái services

---

## 2. `fix-connection.sh` - Fix nhanh kết nối

Script đơn giản để fix kết nối nhanh chóng.

**Sử dụng:**
```bash
./fix-connection.sh
```

**Khi nào dùng:**
- Khi chỉ cần fix kết nối nhanh
- Sau khi restart chatai-spoke
- Khi gặp lỗi `getaddrinfo ENOTFOUND chatai-spoke`

---

## 3. Docker Compose Commands

### Restart tất cả services trong docker-compose:
```bash
docker-compose restart
```

### Restart một service cụ thể:
```bash
docker-compose restart chat-server
```

### Rebuild và restart:
```bash
docker-compose up -d --build chat-server
```

### Xem logs:
```bash
# Logs của tất cả services
docker-compose logs -f

# Logs của một service
docker-compose logs -f chat-server

# Hoặc dùng docker trực tiếp
docker logs -f chat-server
```

---

## Lưu ý

1. **Sau khi restart chatai-spoke**, luôn chạy `./fix-connection.sh` hoặc `./restart-services.sh` để đảm bảo kết nối hoạt động.

2. **Kiểm tra network:**
```bash
docker network inspect chat-be_chat-network
```

3. **Kiểm tra containers đang chạy:**
```bash
docker ps | grep -E "chat|chatai"
```

4. **Test kết nối từ chat-server:**
```bash
docker exec chat-server ping -c 2 chatai-spoke
```

