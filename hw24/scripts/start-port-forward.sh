#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔌 Запуск port-forward для всех сервисов...${NC}"

# Останавливаем старые процессы
pkill -f "kubectl port-forward" 2>/dev/null
sleep 1

# Функция для запуска port-forward
start_pf() {
    local port=$1
    local service=$2
    local logfile="/tmp/pf-$service.log"
    
    nohup kubectl port-forward -n arch-homework service/$service $port:8080 > "$logfile" 2>&1 &
    local pid=$!
    sleep 2
    
    if kill -0 $pid 2>/dev/null; then
        echo -e "${GREEN}✅ $service -> localhost:$port (PID: $pid)${NC}"
        echo $pid >> /tmp/pf-pids.tmp
    else
        echo -e "${RED}❌ $service failed to start${NC}"
        cat "$logfile"
    fi
}

# Запускаем все сервисы
> /tmp/pf-pids.tmp

start_pf 8081 user-service
start_pf 8082 order-service
start_pf 8083 billing-service
start_pf 8084 notification-service

echo ""
echo -e "${GREEN}✅ Port-forward запущен${NC}"
echo "📝 Логи: /tmp/pf-*.log"
echo "   Для остановки: pkill -f 'kubectl port-forward'"
echo ""

# Проверка доступности
echo -e "${YELLOW}🔍 Проверка доступности:${NC}"
for port in 8081 8082 8083 8084; do
    if curl -s http://localhost:$port/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Порт $port доступен${NC}"
    else
        echo -e "${RED}❌ Порт $port недоступен${NC}"
    fi
done
