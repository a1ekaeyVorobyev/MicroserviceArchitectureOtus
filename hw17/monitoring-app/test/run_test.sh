#!/bin/bash
echo "=== Финальный тест системы алертинга ==="

# 1. Запустите нагрузку
echo "1. Запуск нагрузочного теста..."
./load-test.sh > /dev/null 2>&1 &
LOAD_PID=$!

# 2. Ждем метрик
echo "2. Ожидание метрик..."
sleep 30

# 3. Проверка Prometheus
echo "3. Проверка Prometheus..."
METRIC_COUNT=$(curl -s "http://localhost:9090/api/v1/series?match[]={job=\"monitoring-app\"}" | jq '.data | length')
echo "   Метрик приложения: $METRIC_COUNT"

# 4. Проверка Grafana
echo "4. Проверка Grafana..."
RULES=$(curl -s -u admin:admin http://localhost:3000/api/v1/provisioning/alert-rules | jq '. | length')
echo "   Правил: $RULES"

# 5. Остановка нагрузки
kill $LOAD_PID 2>/dev/null
wait $LOAD_PID 2>/dev/null

echo "=== Тест завершен ==="