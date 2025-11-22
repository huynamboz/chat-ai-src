#!/bin/bash

# Script để stop Docker container cho Chat-server_Spoke
# Usage: ./stop.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CONTAINER_NAME="chatai-spoke"

echo -e "${YELLOW}=== Stopping Chat-server_Spoke Container ===${NC}\n"

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    docker stop ${CONTAINER_NAME}
    echo -e "${GREEN}✓ Container stopped successfully${NC}"
else
    echo -e "${YELLOW}Container is not running${NC}"
fi

