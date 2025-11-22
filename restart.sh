#!/bin/bash

# Script để restart Docker container cho Chat-server_Spoke
# Usage: ./restart.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="chatai-spoke"
IMAGE_TAG="latest"
CONTAINER_NAME="chatai-spoke"
ENV_FILE=".env"
HOST_PORT="8001"
CONTAINER_PORT="8001"

echo -e "${GREEN}=== Restarting Chat-server_Spoke Docker Container ===${NC}\n"

# Step 1: Stop existing container
echo -e "${YELLOW}[1/4] Stopping existing container...${NC}"
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    docker stop ${CONTAINER_NAME} 2>/dev/null || true
    echo -e "${GREEN}✓ Container stopped${NC}"
else
    echo -e "${YELLOW}  No existing container found${NC}"
fi

# Step 2: Remove existing container
echo -e "${YELLOW}[2/4] Removing existing container...${NC}"
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    docker rm ${CONTAINER_NAME} 2>/dev/null || true
    echo -e "${GREEN}✓ Container removed${NC}"
else
    echo -e "${YELLOW}  No existing container to remove${NC}"
fi

# Step 3: Build Docker image
echo -e "${YELLOW}[3/4] Building Docker image...${NC}"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Image built successfully${NC}"
else
    echo -e "${RED}✗ Image build failed${NC}"
    exit 1
fi

# Step 4: Check if .env file exists
if [ ! -f "${ENV_FILE}" ]; then
    echo -e "${RED}✗ Error: ${ENV_FILE} file not found!${NC}"
    exit 1
fi

# Step 5: Run new container
echo -e "${YELLOW}[4/4] Starting new container...${NC}"
docker run -d \
    --name ${CONTAINER_NAME} \
    --env-file ${ENV_FILE} \
    -p ${HOST_PORT}:${CONTAINER_PORT} \
    ${IMAGE_NAME}:${IMAGE_TAG}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Container started successfully${NC}\n"
    
    # Wait a moment for container to start
    sleep 2
    
    # Show container status
    echo -e "${GREEN}=== Container Status ===${NC}"
    docker ps | grep ${CONTAINER_NAME} || echo -e "${RED}Container is not running!${NC}"
    
    echo -e "\n${GREEN}=== Recent Logs ===${NC}"
    docker logs ${CONTAINER_NAME} --tail 10
    
    echo -e "\n${GREEN}=== Success! ===${NC}"
    echo -e "Server is running at: ${GREEN}http://localhost:${HOST_PORT}${NC}"
    echo -e "View logs: ${YELLOW}docker logs -f ${CONTAINER_NAME}${NC}"
    echo -e "Stop container: ${YELLOW}docker stop ${CONTAINER_NAME}${NC}"
else
    echo -e "${RED}✗ Failed to start container${NC}"
    exit 1
fi

