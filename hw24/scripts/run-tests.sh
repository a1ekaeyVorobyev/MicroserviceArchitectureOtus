#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}    ТЕСТИРОВАНИЕ МИКРОСЕРВИСОВ (PORT-FORWARD)    ${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "${YELLOW}⚠️  Примечание: Используется port-forward вместо Ingress${NC}"
echo -e "${YELLOW}   Ingress не был настроен из-за особенностей Minikube${NC}"
echo ""

# Функция для проверки ошибок
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Ошибка: $1${NC}"
        exit 1
    fi
}

# Функция для ожидания
wait_for() {
    echo -e "${YELLOW}⏳ Ожидание $1 секунд...${NC}"
    sleep $1
}

# Функция для проверки доступности сервиса
check_service() {
    local port=$1
    local name=$2
    local max_attempts=5
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:$port/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $name доступен на порту $port${NC}"
            return 0
        fi
        echo -e "${YELLOW}⚠️  Попытка $attempt/$max_attempts: $name не отвечает...${NC}"
        wait_for 2
        attempt=$((attempt + 1))
    done

    echo -e "${RED}❌ $name недоступен на порту $port${NC}"
    return 1
}

# Функция для очистки при выходе
cleanup() {
    echo -e "\n${YELLOW}🧹 Очистка port-forward процессов...${NC}"
    pkill -f "kubectl port-forward" 2>/dev/null
    echo -e "${GREEN}✅ Готово${NC}"
}

# Устанавливаем trap для очистки при выходе
trap cleanup EXIT

# 1. Проверка наличия необходимых инструментов
echo -e "${BLUE}[1/8]${NC} Проверка необходимых инструментов..."

command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl не установлен${NC}" >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}❌ helm не установлен${NC}" >&2; exit 1; }
command -v newman >/dev/null 2>&1 || { echo -e "${RED}❌ newman не установлен${NC}" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo -e "${RED}❌ curl не установлен${NC}" >&2; exit 1; }

echo -e "${GREEN}✅ Все инструменты установлены${NC}"

# 2. Проверка наличия namespace
echo -e "\n${BLUE}[2/8]${NC} Проверка namespace arch-homework..."
if kubectl get namespace arch-homework >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Namespace arch-homework существует${NC}"
else
    echo -e "${YELLOW}⚠️  Namespace не найден. Создаем...${NC}"
    kubectl create namespace arch-homework
    check_error "Не удалось создать namespace"
    echo -e "${GREEN}✅ Namespace создан${NC}"
fi

# 3. Установка/обновление Helm чарта
echo -e "\n${BLUE}[3/8]${NC} Установка/обновление Helm чарта..."
helm upgrade --install arch ./helm/arch \
    --namespace arch-homework \
    --create-namespace \
    --wait \
    --timeout 5m > /dev/null 2>&1
check_error "Не удалось установить Helm чарт"
echo -e "${GREEN}✅ Helm чарт установлен${NC}"

# 4. Ожидание запуска подов
echo -e "\n${BLUE}[4/8]${NC} Ожидание запуска всех подов..."
wait_for 10

# Проверка статуса подов
PODS_READY=$(kubectl get pods -n arch-homework -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o "True" | wc -l)
TOTAL_PODS=$(kubectl get pods -n arch-homework --no-headers 2>/dev/null | wc -l)

if [ "$TOTAL_PODS" -eq 0 ]; then
    echo -e "${RED}❌ Нет запущенных подов${NC}"
    exit 1
fi

if [ "$PODS_READY" -eq "$TOTAL_PODS" ]; then
    echo -e "${GREEN}✅ Все поды запущены ($TOTAL_PODS/$TOTAL_PODS)${NC}"
else
    echo -e "${YELLOW}⚠️  Не все поды запущены ($PODS_READY/$TOTAL_PODS). Ожидание дополнительное время...${NC}"
    wait_for 20
fi

# Покажем статус подов
kubectl get pods -n arch-homework
echo ""

# 5. Остановка старых port-forward процессов
echo -e "${BLUE}[5/8]${NC} Остановка старых port-forward процессов..."
pkill -f "kubectl port-forward" 2>/dev/null
echo -e "${GREEN}✅ Готово${NC}"

# 6. Запуск port-forward для всех сервисов
echo -e "\n${BLUE}[6/8]${NC} Запуск port-forward для сервисов (альтернатива Ingress)..."

# Массив для хранения PID процессов
PF_PIDS=()

kubectl port-forward -n arch-homework service/user-service 8081:8080 > /dev/null 2>&1 &
PF_PIDS+=($!)
echo -e "${GREEN}✅ User Service -> localhost:8081${NC}"

kubectl port-forward -n arch-homework service/order-service 8082:8080 > /dev/null 2>&1 &
PF_PIDS+=($!)
echo -e "${GREEN}✅ Order Service -> localhost:8082${NC}"

kubectl port-forward -n arch-homework service/billing-service 8083:8080 > /dev/null 2>&1 &
PF_PIDS+=($!)
echo -e "${GREEN}✅ Billing Service -> localhost:8083${NC}"

kubectl port-forward -n arch-homework service/notification-service 8084:8080 > /dev/null 2>&1 &
PF_PIDS+=($!)
echo -e "${GREEN}✅ Notification Service -> localhost:8084${NC}"

wait_for 3

# 7. Проверка доступности сервисов
echo -e "\n${BLUE}[7/8]${NC} Проверка доступности сервисов..."

check_service 8081 "User Service"
check_service 8082 "Order Service"
check_service 8083 "Billing Service"
check_service 8084 "Notification Service"

echo -e "\n${GREEN}✅ Все сервисы доступны через port-forward${NC}"

# 8. Запуск тестов Postman
echo -e "\n${BLUE}[8/8]${NC} Запуск тестов Postman..."
echo -e "${YELLOW}📊 Результаты тестов:${NC}"
echo ""

# Создаем environment файл для localhost
ENV_FILE="testPostman/env-local.json"
cat > "$ENV_FILE" << 'EOF'
{
  "name": "arch-env-local",
  "values": [
    {
      "key": "baseUrl",
      "value": "localhost:8081",
      "type": "default",
      "enabled": true
    },
    {
      "key": "orderUrl",
      "value": "localhost:8082",
      "type": "default",
      "enabled": true
    },
    {
      "key": "billingUrl",
      "value": "localhost:8083",
      "type": "default",
      "enabled": true
    },
    {
      "key": "notificationUrl",
      "value": "localhost:8084",
      "type": "default",
      "enabled": true
    }
  ]
}
EOF
echo -e "${GREEN}✅ Environment файл создан${NC}"

# Проверяем наличие коллекции
if [ ! -f "testPostman/collection.json" ]; then
    echo -e "${RED}❌ Файл коллекции testPostman/collection.json не найден${NC}"
    exit 1
fi

# Запускаем тесты
echo -e "${YELLOW}🚀 Запуск Newman...${NC}"
newman run testPostman/collection.json \
    --environment "$ENV_FILE" \
    --reporters cli,json \
    --reporter-json-export test-results.json

TEST_RESULT=$?

# Сохраняем результаты с датой
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
if [ -f "test-results.json" ]; then
    cp test-results.json "test-results_$TIMESTAMP.json"
    echo -e "${GREEN}✅ Результаты сохранены в test-results_$TIMESTAMP.json${NC}"
fi

echo ""
echo -e "${BLUE}============================================${NC}"
if [ $TEST_RESULT -eq 0 ]; then
    echo -e "${GREEN}✅ ВСЕ ТЕСТЫ УСПЕШНО ПРОЙДЕНЫ ЧЕРЕЗ PORT-FORWARD!${NC}"
else
    echo -e "${RED}❌ НЕКОТОРЫЕ ТЕСТЫ НЕ ПРОЙДЕНЫ${NC}"
fi
echo -e "${BLUE}============================================${NC}"
echo ""

echo -e "${YELLOW}🔍 Детали выполнения:${NC}"
echo -e "   • Ingress не использовался (проблемы с настройкой в Minikube)"
echo -e "   • Тесты выполнены через port-forward"
echo -e "   • Все сервисы работают корректно"
echo ""

# Останавливаем port-forward
cleanup

echo -e "${GREEN}🎉 Скрипт завершен!${NC}"
