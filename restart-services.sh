#!/bin/bash

# Script để restart các services và fix kết nối giữa chat-server và chatai-spoke
# Sử dụng: ./restart-services.sh

set -e  # Dừng script nếu có lỗi

echo "🚀 Bắt đầu restart services..."

# Màu sắc cho output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Kiểm tra xem chatai-spoke có đang chạy không
if ! docker ps --format '{{.Names}}' | grep -q "^chatai-spoke$"; then
    echo -e "${RED}❌ Container chatai-spoke không đang chạy!${NC}"
    echo "Vui lòng start chatai-spoke trước:"
    echo "  docker start chatai-spoke"
    exit 1
fi

echo -e "${YELLOW}📡 Đang kết nối chatai-spoke vào network chat-be_chat-network...${NC}"

# Kết nối chatai-spoke vào network (bỏ qua lỗi nếu đã kết nối)
docker network connect chat-be_chat-network chatai-spoke 2>/dev/null || \
    echo -e "${GREEN}✓ chatai-spoke đã ở trong network${NC}"

# Kiểm tra xem chat-server có đang chạy không
if docker ps --format '{{.Names}}' | grep -q "^chat-server$"; then
    echo -e "${YELLOW}🔄 Đang restart chat-server...${NC}"
    docker restart chat-server
    echo -e "${GREEN}✓ chat-server đã được restart${NC}"
else
    echo -e "${YELLOW}🚀 Đang start chat-server...${NC}"
    docker-compose up -d chat-server
    echo -e "${GREEN}✓ chat-server đã được start${NC}"
fi

# Đợi một chút để container khởi động
echo -e "${YELLOW}⏳ Đang đợi services khởi động...${NC}"
sleep 3

# Kiểm tra kết nối
echo -e "${YELLOW}🔍 Đang kiểm tra kết nối...${NC}"

if docker exec chat-server ping -c 1 chatai-spoke >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Kết nối network thành công!${NC}"
else
    echo -e "${RED}❌ Không thể ping chatai-spoke từ chat-server${NC}"
    exit 1
fi

# Hiển thị logs gần nhất
echo -e "\n${YELLOW}📋 Logs gần nhất của chat-server:${NC}"
docker logs chat-server --tail 10

echo -e "\n${GREEN}✅ Hoàn tất! Services đã sẵn sàng.${NC}"
echo -e "${YELLOW}💡 Để xem logs real-time: docker logs -f chat-server${NC}"

