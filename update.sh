#!/bin/bash
# Node Auto-Updater
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

{
    # Проверка и обновление контейнера
    if docker ps | grep -q "node"; then
        echo -e "${GREEN}Остановка ноды...${NC}"
        sudo docker stop node
        sudo docker rm node
    fi

    # Получение последней версии
    sudo docker pull chain-image:latest

    # Перезапуск с новым образом
    sudo docker run -d --name node \
        --restart always \
        -v /data/chain:/root/.chain \
        -p 26660:26660 \
        chain-image:latest \
        --metrics --metrics-address 0.0.0.0

    # Проверка обновлений системы
    sudo DEBIAN_FRONTEND=noninteractive apt update -y
    sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

} || {
    echo -e "${RED}ОШИБКА ОБНОВЛЕНИЯ${NC}"
    sudo docker system prune -af
    sudo rm -rf /data/chain
    exit 1
}

# Финал проверки
if docker ps | grep -q "node" && \
   docker images | grep -q "chain-image:latest"; then
    echo -e "${GREEN}НОДА УСПЕШНО ОБНОВЛЕНА${NC}"
else
    echo -e "${RED}ОШИБКА ОБНОВЛЕНИЯ${NC}"
    sudo docker system prune -af
    exit 1
fi
