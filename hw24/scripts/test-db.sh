#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}    ТЕСТИРОВАНИЕ С PORT-FORWARDING    ${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Функция для проверки результата
check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        exit 1
    fi
}

# Функция для проверки доступности порта
check_port() {
    local port=$1
    local service=$2
    if curl -s http://localhost:$port/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $service доступен на порту $port${NC}"
        return 0
    else
        echo -e "${RED}❌ $service НЕ доступен на порту $port${NC}"
        return 1
    fi
}

# Функция для запуска port-forward
start_port_forward() {
    echo -e "${YELLOW}🔌 Запуск port-forward...${NC}"
    
    if [ -f "./start-port-forward.sh" ]; then
        ./start-port-forward.sh
    else
        pkill -f "kubectl port-forward" 2>/dev/null
        kubectl port-forward -n arch-homework service/user-service 8081:8080 > /tmp/pf-user.log 2>&1 &
        kubectl port-forward -n arch-homework service/order-service 8082:8080 > /tmp/pf-order.log 2>&1 &
        kubectl port-forward -n arch-homework service/billing-service 8083:8080 > /tmp/pf-billing.log 2>&1 &
        kubectl port-forward -n arch-homework service/notification-service 8084:8080 > /tmp/pf-notification.log 2>&1 &
        sleep 3
    fi
    
    local success=true
    for port in 8081 8082 8083 8084; do
        if ! curl -s http://localhost:$port/health > /dev/null 2>&1; then
            success=false
            echo -e "${RED}❌ Порт $port не доступен после запуска${NC}"
        fi
    done
    
    if [ "$success" = true ]; then
        echo -e "${GREEN}✅ Port-forward успешно запущен${NC}"
        return 0
    else
        echo -e "${RED}❌ Не удалось запустить port-forward${NC}"
        return 1
    fi
}

# Функция для получения количества уведомлений для конкретного user_id
get_notification_count() {
    local user_id=$1
    local response=$(curl -s "http://localhost:8084/notifications?user_id=$user_id")
    local count=$(echo "$response" | grep -o '"id"' | wc -l | tr -d ' ')
    echo $count
}

# Функция для получения количества уведомлений из БД для конкретного user_id
get_db_count() {
    local user_id=$1
    local count=$(kubectl exec -it -n arch-homework deployment/postgres-notification -- psql -U notification_user -d notifications -t -c "SELECT COUNT(*) FROM notifications WHERE user_id = '$user_id';" 2>/dev/null | tr -d ' ' | tr -d '\r')
    echo $count
}

# Функция для удаления тестовых данных пользователя
cleanup_user_data() {
    local user_id=$1
    if [ ! -z "$user_id" ]; then
        echo -e "${YELLOW}🧹 Очистка данных пользователя $user_id...${NC}"
        kubectl exec -it -n arch-homework deployment/postgres-notification -- psql -U notification_user -d notifications -c "DELETE FROM notifications WHERE user_id = '$user_id';" > /dev/null 2>&1
        echo -e "${GREEN}✅ Данные пользователя $user_id очищены${NC}"
    fi
}

# Переменная для отслеживания, запустили ли мы port-forward
PF_STARTED_BY_US=false

# 0. Проверяем доступность портов
echo -e "${YELLOW}[0/8] Проверка доступности сервисов...${NC}"

PORTS_OK=true
for port in 8081 8082 8083 8084; do
    if ! check_port $port "Service on port $port"; then
        PORTS_OK=false
    fi
done

# Если порты не доступны, запускаем port-forward
if [ "$PORTS_OK" = false ]; then
    echo -e "\n${YELLOW}⚠️  Port-forward не обнаружен. Запускаем...${NC}"
    if start_port_forward; then
        PF_STARTED_BY_US=true
        echo -e "${GREEN}✅ Port-forward запущен автоматически${NC}\n"
    else
        echo -e "${RED}❌ Не удалось запустить port-forward. Прерывание теста.${NC}"
        exit 1
    fi
else
    echo -e "\n${GREEN}✅ Все порты доступны, продолжаем тестирование${NC}\n"
fi

# Генерируем уникальный email для теста
TEST_EMAIL="test_$(date +%s)@example.com"
echo -e "${YELLOW}[1/8] Тестовый email: $TEST_EMAIL${NC}"

# Создаем пользователя
echo -e "\n${YELLOW}[2/8] Создание пользователя...${NC}"
USER_RESPONSE=$(curl -s -X POST http://localhost:8081/users \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\"}")

if [ -z "$USER_RESPONSE" ]; then
    echo -e "${RED}❌ Пустой ответ от сервера${NC}"
    exit 1
fi

USER_ID=$(echo "$USER_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -z "$USER_ID" ]; then
    echo -e "${RED}❌ Не удалось извлечь ID пользователя из ответа${NC}"
    echo "Ответ сервера: $USER_RESPONSE"
    exit 1
fi

echo "   User ID: $USER_ID"
echo "   Response: $USER_RESPONSE"

# Очищаем возможные старые данные этого пользователя
cleanup_user_data "$USER_ID"

# Пополняем счет
echo -e "\n${YELLOW}[3/8] Пополнение счета...${NC}"
DEPOSIT_RESPONSE=$(curl -s -X POST http://localhost:8083/accounts/$USER_ID/deposit \
  -H "Content-Type: application/json" \
  -d '{"amount":200}')
echo "   Response: $DEPOSIT_RESPONSE"

# Создаем успешный заказ
echo -e "\n${YELLOW}[4/8] Создание успешного заказа...${NC}"
ORDER_RESPONSE=$(curl -s -X POST http://localhost:8082/orders \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"$USER_ID\",\"amount\":100,\"email\":\"$TEST_EMAIL\"}")
echo "   Response: $ORDER_RESPONSE"
ORDER_STATUS=$(echo "$ORDER_RESPONSE" | grep -o '"status":"[^"]*' | cut -d'"' -f4)
echo "   Статус заказа: $ORDER_STATUS"

# Проверяем уведомления после первого заказа
sleep 2
echo -e "\n${YELLOW}[5/8] Проверка уведомлений после первого заказа...${NC}"
API_COUNT=$(get_notification_count "$USER_ID")
DB_COUNT=$(get_db_count "$USER_ID")
echo "   Уведомлений в API: $API_COUNT"
echo "   Уведомлений в БД: $DB_COUNT"

if [ "$API_COUNT" -eq 1 ] && [ "$DB_COUNT" -eq 1 ]; then
    echo -e "${GREEN}✅ Первое уведомление сохранено (API и БД)${NC}"
else
    echo -e "${RED}❌ Проблема с первым уведомлением: API=$API_COUNT, БД=$DB_COUNT${NC}"
fi

# Создаем заказ с недостаточными средствами
echo -e "\n${YELLOW}[6/8] Создание заказа с недостаточными средствами...${NC}"
FAIL_ORDER_RESPONSE=$(curl -s -X POST http://localhost:8082/orders \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"$USER_ID\",\"amount\":200,\"email\":\"$TEST_EMAIL\"}")
echo "   Response: $FAIL_ORDER_RESPONSE"
FAIL_STATUS=$(echo "$FAIL_ORDER_RESPONSE" | grep -o '"status":"[^"]*' | cut -d'"' -f4)
echo "   Статус заказа: $FAIL_STATUS"

# Финальная проверка
sleep 2
echo -e "\n${YELLOW}[7/8] Финальная проверка...${NC}"
FINAL_API=$(get_notification_count "$USER_ID")
FINAL_DB=$(get_db_count "$USER_ID")
echo "   Всего уведомлений в API: $FINAL_API"
echo "   Всего уведомлений в БД: $FINAL_DB"

echo -e "\n${YELLOW}[8/8] Детали уведомлений:${NC}"
curl -s "http://localhost:8084/notifications?user_id=$USER_ID" | jq . || echo "Не удалось получить уведомления"

echo -e "\n${BLUE}========================================${NC}"
if [ "$FINAL_API" -eq 2 ] && [ "$FINAL_DB" -eq 2 ]; then
    echo -e "${GREEN}✅ ВСЕ ТЕСТЫ УСПЕШНО ПРОЙДЕНЫ!${NC}"
    echo -e "${GREEN}✅ Создано 2 уведомления для пользователя $USER_ID${NC}"
else
    echo -e "${RED}❌ ТЕСТЫ НЕ ПРОЙДЕНЫ${NC}"
    echo -e "${RED}❌ Ожидалось 2 уведомления, получено: API=$FINAL_API, БД=$FINAL_DB${NC}"
fi
echo -e "${BLUE}========================================${NC}"

# Показываем финальное состояние в БД
echo -e "\n${YELLOW}📊 Данные в PostgreSQL для пользователя $USER_ID:${NC}"
kubectl exec -it -n arch-homework deployment/postgres-notification -- psql -U notification_user -d notifications -c "SELECT id, user_id, message, created_at FROM notifications WHERE user_id = '$USER_ID' ORDER BY created_at DESC;"

# Останавливаем port-forward если сами запускали
if [ "$PF_STARTED_BY_US" = true ]; then
    echo -e "\n${YELLOW}🔌 Остановка port-forward...${NC}"
    pkill -f "kubectl port-forward" 2>/dev/null
    echo -e "${GREEN}✅ Port-forward остановлен${NC}"
fi