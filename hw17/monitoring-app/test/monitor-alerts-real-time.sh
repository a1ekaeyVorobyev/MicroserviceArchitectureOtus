#!/bin/bash

echo "=== Реалтайм мониторинг алертов и метрик ==="
echo "Обновление каждые 10 секунд"
echo "Нажмите Ctrl+C для выхода"
echo ""

while true; do
  clear
  echo "=== $(date) ==="
  echo ""
  
  # Статус сервисов
  echo "📊 Статус сервисов:"
  if docker-compose ps | grep -q "Up"; then
    echo "  ✓ Все сервисы работают"
  else
    echo "  ✗ Есть проблемы с сервисами"
  fi
  echo ""
  
  # Метрики
  echo "📈 Ключевые метрики (последние 2 минуты):"
  
  # Error Rate
  ERROR_RATE=$(curl -s "http://localhost:9090/api/v1/query?query=(sum(rate(http_requests_total{status=~\"5..\"}[2m]))%20/%20(sum(rate(http_requests_total[2m]))%20%2B%200.0001))%20*%20100" | \
    jq -r '.data.result[0].value[1] // "0.00"' 2>/dev/null)
  printf "  Error Rate: %6s%% " "$ERROR_RATE"
  if (( $(echo "$ERROR_RATE > 5" | bc -l 2>/dev/null || echo "0") )); then
    echo "⚠️  (выше порога 5%)"
  else
    echo "✓ (норма)"
  fi
  
  # Latency P95
  LATENCY_P95=$(curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,%20sum%20by(le)%20(rate(http_request_duration_seconds_bucket[2m])))" | \
    jq -r '.data.result[0].value[1] // "0.000"' 2>/dev/null)
  printf "  Latency P95: %6ss " "$LATENCY_P95"
  if (( $(echo "$LATENCY_P95 > 0.5" | bc -l 2>/dev/null || echo "0") )); then
    echo "⚠️  (выше порога 0.5s)"
  else
    echo "✓ (норма)"
  fi
  
  # Latency P99
  LATENCY_P99=$(curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.99,%20sum%20by(le)%20(rate(http_request_duration_seconds_bucket[2m])))" | \
    jq -r '.data.result[0].value[1] // "0.000"' 2>/dev/null)
  printf "  Latency P99: %6ss " "$LATENCY_P99"
  if (( $(echo "$LATENCY_P99 > 1" | bc -l 2>/dev/null || echo "0") )); then
    echo "🚨 (выше порога 1s)"
  else
    echo "✓ (норма)"
  fi
  
  # Request Rate
  REQ_RATE=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total[2m]))" | \
    jq -r '.data.result[0].value[1] // "0.00"' 2>/dev/null)
  echo "  Request Rate: ${REQ_RATE} req/s"
  
  echo ""
  
  # Активные алерты
  echo "🚨 Активные алерты:"
  ALERTS=$(curl -s -u admin:admin http://localhost:3000/api/alertmanager/grafana/api/v2/alerts 2>/dev/null)
  COUNT=$(echo "$ALERTS" | jq '. | length' 2>/dev/null || echo "0")
  
  if [ "$COUNT" -eq 0 ]; then
    echo "  ✓ Нет активных алертов"
  else
    echo "$ALERTS" | jq -r '.[] | 
      "  [\(.labels.severity)] \(.labels.alertname): \(.status.state) (\(.startsAt | fromdateiso8601 | strftime("%H:%M:%S")))"' 2>/dev/null
  fi
  
  echo ""
  echo "🔧 Быстрые команды для тестирования:"
  echo "  1 ошибка:          curl http://localhost:8080/api/force-error"
  echo "  1 успешный запрос: curl http://localhost:8080/api/orders"
  echo "  Медленный запрос:  curl 'http://localhost:8080/api/orders?delay=1500'"
  echo ""
  echo "🔄 Обновление через 10 секунд..."
  sleep 10
done