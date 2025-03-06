#!/bin/bash
# Auto-Update Script for Blockchain Nodes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
LOG_FILE="/var/log/node_update.log"

{
    echo -e "\n$(date) - STARTING UPDATE" >> $LOG_FILE

    # 1. Graceful shutdown
    if docker inspect node &> /dev/null; then
        echo -e "${GREEN}Stopping node...${NC}" | tee -a $LOG_FILE
        timeout 30 docker stop node || docker kill node
        docker rm node | tee -a $LOG_FILE
    fi

    # 2. System updates
    echo -e "${GREEN}Updating system...${NC}" | tee -a $LOG_FILE
    DEBIAN_FRONTEND=noninteractive apt-get update -y | tee -a $LOG_FILE
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y | tee -a $LOG_FILE

    # 3. Docker image update
    echo -e "${GREEN}Pulling new image...${NC}" | tee -a $LOG_FILE
    docker pull chain-image:latest | tee -a $LOG_FILE

    # 4. Restart node
    echo -e "${GREEN}Starting updated node...${NC}" | tee -a $LOG_FILE
    docker run -d \
        --name node \
        --restart unless-stopped \
        -v /data/chain:/root/.chain \
        -p 26660:26660 \
        --health-cmd="curl -s http://localhost:26660/status || exit 1" \
        chain-image:latest | tee -a $LOG_FILE

    # 5. Post-update check
    echo -e "${GREEN}Verifying...${NC}" | tee -a $LOG_FILE
    sleep 10
    if ! docker ps --filter "name=node" --format "{{.Status}}" | grep -q "healthy"; then
        echo -e "${RED}Health check failed!${NC}" | tee -a $LOG_FILE
        exit 1
    fi

    echo -e "${GREEN}Update successful!${NC}" | tee -a $LOG_FILE
    exit 0

} || {
    echo -e "${RED}CRITICAL UPDATE ERROR! Rolling back...${NC}" | tee -a $LOG_FILE
    docker rm -f node | tee -a $LOG_FILE
    docker run -d \
        --name node \
        --restart unless-stopped \
        -v /data/chain:/root/.chain \
        -p 26660:26660 \
        chain-image:previous | tee -a $LOG_FILE
    exit 1
}
