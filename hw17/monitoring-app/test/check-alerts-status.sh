#!/bin/bash

echo "=== Проверка состояния алертов ==="
echo ""

# Проверяем доступность Grafana
if ! curl -s http://localhost:3000/api/health > /dev/null; then
  echo "✗ Grafana недоступна"
  exit 1
fi

echo "✓ Grafana доступна"
echo ""

# Проверяем алерты через API
echo "1. Проверка загруженных правил алертинга..."
RULES_JSON=$(curl -s -u admin:admin http://localhost:3000/api/v1/provisioning/alert-rules 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$RULES_JSON" ]; then
  RULE_COUNT=$(echo "$RULES_JSON" | jq '. | length' 2>/dev/null || echo "0")
  echo "   ✓ Правил загружено: $RULE_COUNT"
  
  if [ "$RULE_COUNT" -gt 0 ]; then
    echo ""
    echo "   Список правил:"
    echo "$RULES_JSON" | jq -r '.[] | "   - \(.title) (состояние: \(.state // "unknown"))"'
  fi
else
  echo "   ✗ Не удалось получить правила алертинга"
  echo "   Проверьте что unified alerting включен"
fi

echo ""
echo "2. Проверка активных алертов..."
ACTIVE_ALERTS=$(curl -s -u admin:admin http://localhost:3000/api/alertmanager/grafana/api/v2/alerts 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$ACTIVE_ALERTS" ]; then
  ACTIVE_COUNT=$(echo "$ACTIVE_ALERTS" | jq '. | length' 2>/dev/null || echo "0")
  echo "   ✓ Активных алертов: $ACTIVE_COUNT"
  
  if [ "$ACTIVE_COUNT" -gt 0 ]; then
    echo ""
    echo "   Активные алерты:"
    echo "$ACTIVE_ALERTS" | jq -r '.[] | "   - \(.labels.alertname): \(.status.state)"'
  fi
else
  echo "   ℹ Нет активных алертов или API не доступен"
fi

echo ""
echo "3. Генерация тестовых данных для проверки алертов..."
echo "   Отправка запросов (5 ошибок, 5 успешных)..."
for i in {1..5}; do
  curl -s "http://localhost:8080/api/force-error" > /dev/null && echo -n "E"
  curl -s "http://localhost:8080/api/orders" > /dev/null && echo -n "."
  sleep 0.5
done
echo ""
echo "   ✓ Тестовые данные сгенерированы"

echo ""
echo "4. Проверка метрик в Prometheus..."
echo "   Error Rate за последние 5 минут:"
ERROR_RATE=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{status=~\"5..\"}[5m]))%20/%20sum(rate(http_requests_total[5m]))%20*%20100")
echo "$ERROR_RATE" | jq -r '.data.result[]? | "     Значение: \(.value[1])%"' 2>/dev/null || echo "     Нет данных"

echo ""
echo "   Latency P95 за последние 5 минут:"
LATENCY_P95=$(curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,%20rate(http_request_duration_seconds_bucket[5m]))")
echo "$LATENCY_P95" | jq -r '.data.result[]? | "     Значение: \(.value[1])s"' 2>/dev/null || echo "     Нет данных"

echo ""
echo "=== Сводка ==="
echo "Grafana: http://localhost:3000 (admin/admin)"
echo "Prometheus: http://localhost:9090"
echo "Приложение: http://localhost:8080"
echo ""
echo "Для проверки алертов откройте: http://localhost:3000/alerting/list"