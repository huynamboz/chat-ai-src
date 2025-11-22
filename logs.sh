#!/bin/bash

# Script để xem logs của Docker container
# Usage: ./logs.sh [number_of_lines]
# Example: ./logs.sh 50 (xem 50 dòng cuối)
#          ./logs.sh (xem real-time logs)

CONTAINER_NAME="chatai-spoke"

if [ -z "$1" ]; then
    # No argument, show real-time logs
    echo "Showing real-time logs (Press Ctrl+C to exit)..."
    docker logs -f ${CONTAINER_NAME}
else
    # Show last N lines
    docker logs --tail $1 ${CONTAINER_NAME}
fi

