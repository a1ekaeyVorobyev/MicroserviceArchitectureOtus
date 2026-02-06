#!/bin/bash

GRAFANA_URL="http://localhost:3000"
AUTH="admin:admin"

echo "=== Мониторинг алертов ==="
echo "Обновляется каждые 10 секунд (Ctrl+C для выхода)"
echo ""

while true; do
  clear
  echo "=== $(date) ==="
  
  # Активные алерты
  ACTIVE=$(curl -s -u $AUTH $GRAFANA_URL/api/alertmanager/grafana/api/v2/alerts)
  COUNT=$(echo "$ACTIVE" | jq '. | length')
  
  if [ "$COUNT" -eq 0 ]; then
    echo "✅ Нет активных алертов"
  else
    echo "🚨 АКТИВНЫЕ АЛЕРТЫ ($COUNT):"
    echo "$ACTIVE" | jq -r '.[] | "  🔴 \(.labels.alertname) - \(.status.state)\n    С: \(.startsAt)\n    Аннотации: \(.annotations | to_entries[] | "\(.key)=\(.value)")\n"'
  fi
  
  # Состояние правил
  echo -e "\n📊 Состояние правил:"
  RULES=$(curl -s -u $AUTH $GRAFANA_URL/api/v1/provisioning/alert-rules)
  echo "$RULES" | jq -r '.[] | "  \(.title): \(.state)"'
  
  # Метрики
  echo -e "\n📈 Метрики:"
  ERROR_RATE=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{status=~\"5..\"}[1m])) / sum(rate(http_requests_total[1m])) * 100" | jq -r '.data.result[0].value[1] // "0"')
  echo "  Error Rate: ${ERROR_RATE:0:5}%"
  
  LATENCY=$(curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1m]))" | jq -r '.data.result[0].value[1] // "0"')
  echo "  Latency p95: ${LATENCY:0:6}s"
  
  echo -e "\n🔄 Обновление через 10 сек..."
  sleep 10
done
