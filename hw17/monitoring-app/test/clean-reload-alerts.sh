#!/bin/bash

echo "=== Полная очистка и перезагрузка алертов ==="
echo ""

# 1. Удаляем все существующие правила через API
echo "1. Удаление всех существующих правил..."
RULES=$(curl -s -u admin:admin http://localhost:3000/api/v1/provisioning/alert-rules 2>/dev/null)

if [ -n "$RULES" ] && [ "$RULES" != "[]" ]; then
  echo "$RULES" | jq -r '.[].uid' | while read uid; do
    echo "   Удаление правила UID: $uid"
    curl -s -u admin:admin -X DELETE "http://localhost:3000/api/v1/provisioning/alert-rules/$uid" > /dev/null
  done
  echo "   ✓ Все правила удалены"
else
  echo "   ℹ Нет правил для удаления"
fi
echo ""

# 2. Ждем
sleep 3

# 3. Проверяем что правил нет
echo "2. Проверка что правил нет..."
COUNT=$(curl -s -u admin:admin http://localhost:3000/api/v1/provisioning/alert-rules | jq '. | length' 2>/dev/null || echo "0")
if [ "$COUNT" -eq 0 ]; then
  echo "   ✓ Правил нет"
else
  echo "   ✗ Осталось правил: $COUNT"
  exit 1
fi
echo ""

# 4. Упрощаем конфигурацию (основные 4 правила)
echo "3. Создание чистой конфигурации..."

cat > grafana/provisioning/alerting/alert-rules-clean.yml << 'EOF'
apiVersion: 1

groups:
  - name: error-rate-alerts
    folder: "Go Monitoring"
    interval: 1m
    orgId: 1
    rules:
      # Тестовое правило для проверки работы
      - uid: test_alert_working
        title: "Test Alert - Working"
        condition: "A"
        data:
          - refId: "A"
            datasourceUid: "prometheus-main"
            relativeTimeRange:
              from: 300
              to: 0
            model:
              expr: "up{job=\"monitoring-app\"}"
              instant: true
              interval: 1m
              datasource:
                type: "prometheus"
                uid: "prometheus-main"
              refId: "A"
        noDataState: "NoData"
        execErrState: "Alerting"
        for: 0s
        annotations:
          summary: "Service is up"
        labels:
          severity: "info"
          team: "backend"

      # Правило для Error Rate
      - uid: error_rate_high
        title: "High Error Rate (> 5%)"
        condition: "A"
        data:
          - refId: "A"
            datasourceUid: "prometheus-main"
            relativeTimeRange:
              from: 300
              to: 0
            model:
              expr: "sum(rate(http_requests_total{status=~\"5..\"}[2m])) / sum(rate(http_requests_total[2m])) * 100 > 5"
              instant: true
              interval: 1m
              datasource:
                type: "prometheus"
                uid: "prometheus-main"
              refId: "A"
        noDataState: "NoData"
        execErrState: "Alerting"
        for: 2m
        annotations:
          summary: "High error rate detected"
        labels:
          severity: "warning"
          team: "backend"

  - name: latency-alerts
    folder: "Go Monitoring"
    interval: 1m
    orgId: 1
    rules:
      # Правило для P95 Latency
      - uid: latency_p95_high
        title: "High Latency P95 (> 0.5s)"
        condition: "A"
        data:
          - refId: "A"
            datasourceUid: "prometheus-main"
            relativeTimeRange:
              from: 300
              to: 0
            model:
              expr: "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[2m])) > 0.5"
              instant: true
              interval: 1m
              datasource:
                type: "prometheus"
                uid: "prometheus-main"
              refId: "A"
        noDataState: "NoData"
        execErrState: "Alerting"
        for: 2m
        annotations:
          summary: "High P95 latency detected"
        labels:
          severity: "warning"
          team: "backend"

      # Правило для P99 Latency
      - uid: latency_p99_critical
        title: "Critical Latency P99 (> 1s)"
        condition: "A"
        data:
          - refId: "A"
            datasourceUid: "prometheus-main"
            relativeTimeRange:
              from: 300
              to: 0
            model:
              expr: "histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[2m])) > 1"
              instant: true
              interval: 1m
              datasource:
                type: "prometheus"
                uid: "prometheus-main"
              refId: "A"
        noDataState: "NoData"
        execErrState: "Alerting"
        for: 1m
        annotations:
          summary: "Critical P99 latency detected"
        labels:
          severity: "critical"
          team: "backend"
EOF

# Копируем как основную конфигурацию
cp grafana/provisioning/alerting/alert-rules-clean.yml grafana/provisioning/alerting/alert-rules.yml
echo "   ✓ Чистая конфигурация создана (4 основных правила)"
echo ""

# 5. Перезапускаем Grafana
echo "4. Перезапуск Grafana..."
docker-compose restart grafana
echo "   ✓ Grafana перезапущена"
echo ""

# 6. Ожидание
echo "5. Ожидание запуска и загрузки правил (20 секунд)..."
sleep 20

# 7. Проверка
echo "6. Проверка загруженных правил..."
RULES_AFTER=$(curl -s -u admin:admin http://localhost:3000/api/v1/provisioning/alert-rules)
COUNT_AFTER=$(echo "$RULES_AFTER" | jq '. | length' 2>/dev/null || echo "0")

echo "   Загружено правил: $COUNT_AFTER"
echo ""

if [ "$COUNT_AFTER" -gt 0 ]; then
  echo "   Список правил (должно быть 4):"
  echo "$RULES_AFTER" | jq -r '.[] | "     - \(.title) (UID: \(.uid), состояние: \(.state // "unknown"))"'
  
  # Проверяем дубликаты
  echo ""
  echo "   Проверка на дубликаты:"
  TITLES=$(echo "$RULES_AFTER" | jq -r '.[].title' | sort)
  UNIQUE_TITLES=$(echo "$TITLES" | uniq)
  DUPLICATES=$(echo "$TITLES" | uniq -d)
  
  if [ -n "$DUPLICATES" ]; then
    echo "   ✗ Найдены дубликаты:"
    echo "$DUPLICATES" | while read title; do
      echo "     - $title"
    done
  else
    echo "   ✓ Дубликатов нет"
  fi
else
  echo "   ✗ Правила не загрузились"
fi

echo ""
echo "=== Очистка завершена ==="
echo ""
echo "Проверьте:"
echo "  - http://localhost:3000/alerting/list"
echo "  - Должно быть 4 правила без дубликатов"