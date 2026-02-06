#!/bin/bash

GRAFANA_URL="http://localhost:3000"
AUTH="admin:admin"

echo "=== Проверка алертов Grafana ==="
echo "Время: $(date)"
echo ""

# 1. Проверка доступности Grafana
echo "1. Проверка доступности Grafana..."
if ! curl -s -f $GRAFANA_URL/api/health > /dev/null; then
  echo "   ✗ Grafana недоступна"
  exit 1
fi
echo "   ✓ Grafana доступна"

# 2. Проверка количества правил
echo -e "\n2. Проверка правил алертов..."
RULES_JSON=$(curl -s -u $AUTH $GRAFANA_URL/api/v1/provisioning/alert-rules)
RULE_COUNT=$(echo "$RULES_JSON" | jq '. | length')
echo "   Всего правил: $RULE_COUNT"

if [ "$RULE_COUNT" -gt 0 ]; then
  echo "   Детали правил:"
  echo "$RULES_JSON" | jq -r '.[] | "   - \(.title) (группа: \(.ruleGroup), папка: \(.folderUID), состояние: \(.state))"'
fi

# 3. Проверка активных алертов
echo -e "\n3. Проверка активных алертов..."
ACTIVE_ALERTS=$(curl -s -u $AUTH $GRAFANA_URL/api/alertmanager/grafana/api/v2/alerts)
ACTIVE_COUNT=$(echo "$ACTIVE_ALERTS" | jq '. | length')
echo "   Активных алертов: $ACTIVE_COUNT"

if [ "$ACTIVE_COUNT" -gt 0 ]; then
  echo "   Активные алерты:"
  echo "$ACTIVE_ALERTS" | jq -r '.[] | "   - \(.labels.alertname): \(.status.state) (с \(.startsAt))"'
fi

# 4. Проверка папок
echo -e "\n4. Проверка папок..."
FOLDERS=$(curl -s -u $AUTH $GRAFANA_URL/api/folders)
echo "   Папки:"
echo "$FOLDERS" | jq -r '.[] | "   - \(.title) (UID: \(.uid))"'

# 5. Проверка источника данных
echo -e "\n5. Проверка источника данных..."
DATASOURCES=$(curl -s -u $AUTH $GRAFANA_URL/api/datasources)
PROMETHEUS_UID=$(echo "$DATASOURCES" | jq -r '.[] | select(.name=="Prometheus") | .uid')
if [ -n "$PROMETHEUS_UID" ]; then
  echo "   ✓ Prometheus найден (UID: $PROMETHEUS_UID)"
else
  echo "   ✗ Prometheus не найден"
fi

# 6. Проверка метрик в Prometheus
echo -e "\n6. Проверка метрик в Prometheus..."
echo "   Проверка метрики http_requests_total:"
curl -s "http://localhost:9090/api/v1/query?query=http_requests_total" | \
  jq -r '.data.result[0:2][] | "   - \(.metric) = \(.value[1])"' 2>/dev/null || echo "   ✗ Метрика не найдена"

echo -e "\n   Проверка метрики http_request_duration_seconds_bucket:"
curl -s "http://localhost:9090/api/v1/query?query=http_request_duration_seconds_bucket" | \
  jq -r '.data.result[0:2][] | "   - \(.metric) = \(.value[1])"' 2>/dev/null || echo "   ✗ Метрика не найдена"

# 7. Проверка выражений алертов
echo -e "\n7. Проверка выражений алертов:"
if [ "$RULE_COUNT" -gt 0 ]; then
  echo "$RULES_JSON" | jq -r '.[] | "   \(.title):" + "\n     Запрос: \(.data[0].model.expr)"'
fi

# 8. Проверка состояния выражений
echo -e "\n8. Проверка состояния выражений через Prometheus..."
echo "   Error Rate (5 минут):"
ERROR_RATE=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{status=~\"5..\"}[5m]))%20/%20sum(rate(http_requests_total[5m]))%20*%20100")
echo "$ERROR_RATE" | jq -r '.data.result[]? | "     Значение: \(.value[1])%"' || echo "     Нет данных"

echo -e "\n   Latency P95 (5 минут):"
LATENCY_P95=$(curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,%20rate(http_request_duration_seconds_bucket[5m]))")
echo "$LATENCY_P95" | jq -r '.data.result[]? | "     Значение: \(.value[1])s"' || echo "     Нет данных"

# 9. Сводка
echo -e "\n=== Сводка ==="
echo "Правила: $RULE_COUNT"
echo "Активные алерты: $ACTIVE_COUNT"
echo "Папка 'Go Monitoring': $(echo "$FOLDERS" | jq -r '.[] | select(.title=="Go Monitoring") | "существует" // "не найдена")"
echo "Prometheus UID в системе: $PROMETHEUS_UID"

# 10. Проверка несовпадения UID
if [ "$PROMETHEUS_UID" != "prometheus-main" ]; then
  echo -e "\n⚠️  Внимание: UID Prometheus в правилах (prometheus-main) не совпадает с фактическим ($PROMETHEUS_UID)"
  echo "   Это может быть причиной проблем с оценкой выражений!"
fi

echo -e "\nСсылки:"
echo "   Grafana Alerts: http://localhost:3000/alerting/list"
echo "   Prometheus: http://localhost:9090"
echo "   Приложение: http://localhost:8080"
echo -e "\nДля генерации нагрузки:"
echo "   curl http://localhost:8080/api/force-error  # генерация ошибок"
echo "   curl http://localhost:8080/api/orders       # нормальный запрос"