#!/bin/bash

echo "=== Финальный тест алертов Error Rate и Latency ==="
echo ""

# Генерация тестовых данных
echo "1. Генерация тестовых данных..."
echo "   Цель: вызвать срабатывание Error Rate и Latency алертов"

# Создаем высокий error rate (~66%)
echo "   Этап 1: High Error Rate..."
for i in {1..40}; do
  curl -s "http://localhost:8080/api/force-error" > /dev/null
  echo -n "E"
  sleep 0.1
done
for i in {1..20}; do
  curl -s "http://localhost:8080/api/orders" > /dev/null
  echo -n "."
  sleep 0.1
done

echo ""
echo "   Этап 2: High Latency..."
for i in {1..10}; do
  curl -s "http://localhost:8080/api/orders?delay=1500" > /dev/null
  echo -n "S"
  sleep 0.5
done

echo ""
echo "   ✓ Тестовые данные сгенерированы"
echo ""

# Ждем
echo "2. Ожидание сбора метрик (40 секунд)..."
sleep 40

# Проверка метрик
echo "3. Проверка метрик:"

# Error Rate
ERROR_RATE=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{status=~\"5..\"}[2m]))%20/%20sum(rate(http_requests_total[2m]))%20*%20100")
ERROR_VALUE=$(echo "$ERROR_RATE" | jq -r '.data.result[0].value[1] // "0"')
echo "   Error Rate: ${ERROR_VALUE}% (порог: > 5%)"

if (( $(echo "$ERROR_VALUE > 5" | bc -l 2>/dev/null || echo "0") )); then
  echo "   ⚠️  Превышен порог! Алерт 'High Error Rate (> 5%)' должен сработать"
  ERROR_TRIGGERED=true
else
  echo "   ✗ Ниже порога"
  ERROR_TRIGGERED=false
fi

# Latency P95
LATENCY_P95=$(curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,%20rate(http_request_duration_seconds_bucket[2m]))")
LATENCY_P95_VALUE=$(echo "$LATENCY_P95" | jq -r '.data.result[0].value[1] // "0"')
echo "   Latency P95: ${LATENCY_P95_VALUE}s (порог: > 0.5s)"

if (( $(echo "$LATENCY_P95_VALUE > 0.5" | bc -l 2>/dev/null || echo "0") )); then
  echo "   ⚠️  Превышен порог! Алерт 'High Latency P95 (> 0.5s)' должен сработать"
  LATENCY_P95_TRIGGERED=true
else
  echo "   ✗ Ниже порога"
  LATENCY_P95_TRIGGERED=false
fi

# Latency P99
LATENCY_P99=$(curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.99,%20rate(http_request_duration_seconds_bucket[2m]))")
LATENCY_P99_VALUE=$(echo "$LATENCY_P99" | jq -r '.data.result[0].value[1] // "0"')
echo "   Latency P99: ${LATENCY_P99_VALUE}s (порог: > 1s)"

if (( $(echo "$LATENCY_P99_VALUE > 1" | bc -l 2>/dev/null || echo "0") )); then
  echo "   ⚠️  Превышен порог! Алерт 'Critical Latency P99 (> 1s)' должен сработать"
  LATENCY_P99_TRIGGERED=true
else
  echo "   ✗ Ниже порога"
  LATENCY_P99_TRIGGERED=false
fi

# Ждем срабатывания алертов
echo ""
echo "4. Ожидание срабатывания алертов (правила имеют for: 2m и for: 1m)..."
echo "   Проверка через 90 секунд..."
sleep 90

# Проверка состояния алертов
echo ""
echo "5. Проверка состояния алертов:"
RULES=$(curl -s -u admin:admin http://localhost:3000/api/v1/provisioning/alert-rules 2>/dev/null || echo "[]")

echo "   Состояние каждого правила:"
echo "$RULES" | jq -r '.[] | select(.title != "Test Alert - Working") | "     \(.title): \(.state // "unknown")"' | sort

# Подсчет
ALERTING_COUNT=$(echo "$RULES" | jq '[.[] | select(.state == "Alerting")] | length' 2>/dev/null || echo "0")
PENDING_COUNT=$(echo "$RULES" | jq '[.[] | select(.state == "Pending")] | length' 2>/dev/null || echo "0")

echo ""
echo "   Статистика:"
echo "     Alerting: $ALERTING_COUNT"
echo "     Pending: $PENDING_COUNT"

# Активные алерты
echo ""
echo "6. Активные алерты (Alert Manager):"
ACTIVE=$(curl -s -u admin:admin http://localhost:3000/api/alertmanager/grafana/api/v2/alerts 2>/dev/null || echo "[]")
ACTIVE_COUNT=$(echo "$ACTIVE" | jq '. | length // 0')
echo "   Количество активных алертов: $ACTIVE_COUNT"

if [ "$ACTIVE_COUNT" -gt 0 ]; then
  echo "   Список:"
  echo "$ACTIVE" | jq -r '.[] | "     - \(.labels.alertname) (\(.labels.severity)): \(.status.state)"'
fi

echo ""
echo "=== Тест завершен ==="
echo ""
echo "Итог:"
echo "  - Error Rate: ${ERROR_VALUE}% (порог: 5%)"
echo "  - Latency P95: ${LATENCY_P95_VALUE}s (порог: 0.5s)"
echo "  - Latency P99: ${LATENCY_P99_VALUE}s (порог: 1s)"
echo "  - Alerting правил: $ALERTING_COUNT"
echo "  - Активных алертов: $ACTIVE_COUNT"
echo ""
echo "Ожидаемое поведение:"
if $ERROR_TRIGGERED; then
  echo "  ✓ Error Rate > 5% - алерт должен быть Alerting или Pending"
else
  echo "  ✗ Error Rate ≤ 5% - алерт будет Normal"
fi

if $LATENCY_P95_TRIGGERED; then
  echo "  ✓ Latency P95 > 0.5s - алерт должен быть Alerting или Pending"
else
  echo "  ✗ Latency P95 ≤ 0.5s - алерт будет Normal"
fi

if $LATENCY_P99_TRIGGERED; then
  echo "  ✓ Latency P99 > 1s - алерт должен быть Alerting или Pending"
else
  echo "  ✗ Latency P99 ≤ 1s - алерт будет Normal"
fi

echo ""
echo "Проверьте вручную:"
echo "  - http://localhost:3000/alerting/list"
echo "  - http://localhost:9090"