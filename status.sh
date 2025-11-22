#!/bin/bash

# Script để xem status của Docker container
# Usage: ./status.sh

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CONTAINER_NAME="chatai-spoke"

echo -e "${YELLOW}=== Container Status ===${NC}\n"

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${GREEN}✓ Container is RUNNING${NC}\n"
    docker ps | grep ${CONTAINER_NAME}
    echo -e "\n${YELLOW}=== Recent Logs (last 10 lines) ===${NC}"
    docker logs --tail 10 ${CONTAINER_NAME}
else
    echo -e "${RED}✗ Container is NOT running${NC}\n"
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}Container exists but is stopped${NC}"
        docker ps -a | grep ${CONTAINER_NAME}
    else
        echo -e "${YELLOW}Container does not exist${NC}"
    fi
fi

