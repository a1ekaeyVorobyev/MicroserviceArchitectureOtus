#!/bin/bash

echo "=== Полный тест алертов Error Rate и Latency ==="
echo ""

# 1. Проверяем текущее состояние
echo "1. Текущее состояние системы:"
echo "   Grafana: http://localhost:3000"
echo "   Prometheus: http://localhost:9090"
echo "   Приложение: http://localhost:8080"
echo ""

# Проверяем доступность
if ! curl -s http://localhost:3000/api/health > /dev/null; then
  echo "✗ Grafana недоступна"
  exit 1
fi
echo "✓ Все сервисы доступны"
echo ""

# 2. Проверяем текущие алерты
echo "2. Проверка текущих алертов перед тестом..."
ALERTS_BEFORE=$(curl -s -u admin:admin http://localhost:3000/api/alertmanager/grafana/api/v2/alerts 2>/dev/null)
COUNT_BEFORE=$(echo "$ALERTS_BEFORE" | jq '. | length' 2>/dev/null || echo "0")
echo "   Активных алертов: $COUNT_BEFORE"

if [ "$COUNT_BEFORE" -gt 0 ]; then
  echo "   Текущие алерты:"
  echo "$ALERTS_BEFORE" | jq -r '.[] | "     - \(.labels.alertname): \(.status.state)"' 2>/dev/null
fi
echo ""

# 3. Этап 1: Тестирование Error Rate алерта
echo "3. === Тестирование Error Rate алерта ==="
echo "   Цель: Создать error rate > 5%"
echo "   Метод: Отправка 70% ошибок, 30% успешных запросов"
echo ""

ERROR_COUNT=35   # 70%
SUCCESS_COUNT=15 # 30%

echo "   Отправка $ERROR_COUNT ошибок..."
for i in $(seq 1 $ERROR_COUNT); do
  curl -s "http://localhost:8080/api/force-error" > /dev/null
  echo -n "E"
  sleep 0.05
done

echo ""
echo "   Отправка $SUCCESS_COUNT успешных запросов..."
for i in $(seq 1 $SUCCESS_COUNT); do
  curl -s "http://localhost:8080/api/orders" > /dev/null
  echo -n "."
  sleep 0.05
done

echo ""
echo "   ✓ Тестовые данные отправлены"
echo "   Ожидание сбора метрик (20 секунд)..."
sleep 20

echo ""
echo "   Текущий Error Rate (2 минуты):"
ERROR_RATE=$(curl -s "http://localhost:9090/api/v1/query?query=(sum(rate(http_requests_total{status=~\"5..\"}[2m]))%20/%20(sum(rate(http_requests_total[2m]))%20%2B%200.0001))%20*%20100" | \
  jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)
echo "     $ERROR_RATE% (порог: > 5%)"

if (( $(echo "$ERROR_RATE > 5" | bc -l 2>/dev/null || echo "0") )); then
  echo "     ✓ Error rate превышает порог - алерт должен сработать"
else
  echo "     ✗ Error rate ниже порога"
fi
echo ""

# 4. Этап 2: Тестирование Latency алертов
echo "4. === Тестирование Latency алертов ==="
echo "   Цель: Создать высокую latency (P95 > 0.5s, P99 > 1s)"
echo "   Метод: Отправка медленных запросов"
echo ""

SLOW_COUNT=20
FAST_COUNT=10

echo "   Отправка $SLOW_COUNT медленных запросов (1.5 секунд)..."
for i in $(seq 1 $SLOW_COUNT); do
  curl -s "http://localhost:8080/api/orders?delay=1500" > /dev/null
  echo -n "S"
  sleep 0.3
done

echo ""
echo "   Отправка $FAST_COUNT быстрых запросов..."
for i in $(seq 1 $FAST_COUNT); do
  curl -s "http://localhost:8080/api/orders" > /dev/null
  echo -n "F"
  sleep 0.1
done

echo ""
echo "   ✓ Тестовые данные отправлены"
echo "   Ожидание сбора метрик (20 секунд)..."
sleep 20

echo ""
echo "   Текущая Latency (2 минуты):"
LATENCY_P95=$(curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,%20sum%20by(le)%20(rate(http_request_duration_seconds_bucket[2m])))" | \
  jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)
LATENCY_P99=$(curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.99,%20sum%20by(le)%20(rate(http_request_duration_seconds_bucket[2m])))" | \
  jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)

echo "     P95: $LATENCY_P95 секунд (порог: > 0.5s)"
echo "     P99: $LATENCY_P99 секунд (порог: > 1s)"

if (( $(echo "$LATENCY_P95 > 0.5" | bc -l 2>/dev/null || echo "0") )); then
  echo "     ✓ P95 latency превышает порог - алерт должен сработать"
else
  echo "     ✗ P95 latency ниже порога"
fi

if (( $(echo "$LATENCY_P99 > 1" | bc -l 2>/dev/null || echo "0") )); then
  echo "     ✓ P99 latency превышает порог - критический алерт должен сработать"
else
  echo "     ✗ P99 latency ниже порога"
fi
echo ""

# 5. Ожидание срабатывания алертов
echo "5. Ожидание срабатывания алертов (2 минуты)..."
echo "   Алерты имеют for: 2m и for: 1m, поэтому нужно подождать"
echo "   Проверка через:"
for i in {1..8}; do
  echo "   $((i*15)) секунд..."
  sleep 15
done
echo ""

# 6. Финальная проверка
echo "6. === Финальная проверка алертов ==="
ALERTS_AFTER=$(curl -s -u admin:admin http://localhost:3000/api/alertmanager/grafana/api/v2/alerts 2>/dev/null)
COUNT_AFTER=$(echo "$ALERTS_AFTER" | jq '. | length' 2>/dev/null || echo "0")

echo "   Активных алертов после теста: $COUNT_AFTER"
echo ""

if [ "$COUNT_AFTER" -gt 0 ]; then
  echo "   Сработавшие алерты:"
  echo "$ALERTS_AFTER" | jq -r '.[] | "     - \(.labels.alertname) (\(.labels.severity)): \(.status.state) (с \(.startsAt))"' 2>/dev/null
  
  # Подсчет по типам
  ERROR_ALERTS=$(echo "$ALERTS_AFTER" | jq '[.[] | select(.labels.alertname | contains("Error"))] | length' 2>/dev/null || echo "0")
  LATENCY_ALERTS=$(echo "$ALERTS_AFTER" | jq '[.[] | select(.labels.alertname | contains("Latency"))] | length' 2>/dev/null || echo "0")
  
  echo ""
  echo "   Итог по типам:"
  echo "     Error Rate алертов: $ERROR_ALERTS"
  echo "     Latency алертов: $LATENCY_ALERTS"
else
  echo "   ✗ Ни один алерт не сработал"
  echo ""
  echo "   Возможные причины:"
  echo "     1. Недостаточно данных (нужно больше времени)"
  echo "     2. Пороги слишком высокие"
  echo "     3. Проблемы с выражениями"
fi

echo ""
echo "=== Тест завершен ==="
echo ""
echo "Ручная проверка:"
echo "  1. Откройте Grafana: http://localhost:3000/alerting/list"
echo "  2. Проверьте состояние всех алертов"
echo "  3. Посмотрите графики в дашборде"
echo ""
echo "Для повторного теста с другими параметрами:"
echo "  Высокий error rate:   for i in {1..100}; do curl http://localhost:8080/api/force-error; done"
echo "  Высокая latency:      for i in {1..50}; do curl 'http://localhost:8080/api/orders?delay=2000'; sleep 0.5; done"