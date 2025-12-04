#!/bin/bash

# Script nhanh để fix kết nối giữa chat-server và chatai-spoke
# Sử dụng: ./fix-connection.sh

set -e

echo "🔧 Đang fix kết nối..."

# Kết nối chatai-spoke vào network (ignore error nếu đã kết nối)
docker network connect chat-be_chat-network chatai-spoke 2>/dev/null || true

# Restart chat-server để refresh DNS
if docker ps --format '{{.Names}}' | grep -q "^chat-server$"; then
    docker restart chat-server >/dev/null 2>&1
    echo "✅ Đã restart chat-server"
else
    echo "⚠️  chat-server không đang chạy"
fi

echo "✅ Hoàn tất!"

