#!/bin/bash
# Blockchain Node Setup
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
MONITOR_IP="10.0.0.100"  # Заменить на IP сервера мониторинга
CHAIN_DATA="/data/chain"  # Папка для данных блокчейна

{
    # Установка базовых компонентов
    sudo DEBIAN_FRONTEND=noninteractive apt update -y
    sudo DEBIAN_FRONTEND=noninteractive apt install -y docker.io screen prometheus-node-exporter jq
    
    # Настройка безопасности
    sudo ufw allow from $MONITOR_IP to any port 9100  # Node Exporter
    sudo ufw allow from $MONITOR_IP to any port 26660 # Метрики ноды
    
    # Инициализация данных
    sudo mkdir -p $CHAIN_DATA
    sudo chmod 777 $CHAIN_DATA
    
    # Запуск ноды в screen
    screen -dmS node bash -c "docker run -d --name node \
        --restart always \
        -v $CHAIN_DATA:/root/.chain \
        -p 26660:26660 \
        chain-image:latest \
        --metrics --metrics-address 0.0.0.0"
    
    # Systemd-юнит
    sudo tee /etc/systemd/system/node.service > /dev/null <<EOL
[Unit]
Description=Blockchain Node
After=docker.service

[Service]
ExecStart=/usr/bin/docker start -a node
ExecStop=/usr/bin/docker stop node
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

    # Настройка метрик
    sudo tee /etc/prometheus/node_exporter/custom_metrics.sh <<'EOL'
#!/bin/bash
NODE_STATUS=$(curl -s http://localhost:26660/status | jq -r '.status')
echo "node_status{instance=\"$HOSTNAME\"} $NODE_STATUS"
EOL
    
    sudo chmod +x /etc/prometheus/node_exporter/custom_metrics.sh
    sudo systemctl daemon-reload
    sudo systemctl enable --now node.service prometheus-node-exporter

} || {
    echo -e "${RED}ОШИБКА УСТАНОВКИ!${NC}"
    sudo docker system prune -af
    sudo rm -rf $CHAIN_DATA
    exit 1
}

# Проверка
if docker ps | grep -q "node" && \
   curl -s http://$MONITOR_IP:9090/api/v1/targets | grep -q "UP"; then
    echo -e "\n${GREEN}НОДА УСПЕШНО ЗАПУЩЕНА${NC}"
    echo "Метрики: http://$MONITOR_IP:3000/d/blockchain-dashboard"
else
    echo -e "\n${RED}ОШИБКА: НОДА НЕ ЗАПУСТИЛАСЬ${NC}"
    sudo docker logs node --tail 50
    exit 1
fi
