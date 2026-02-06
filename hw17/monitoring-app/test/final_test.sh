#!/bin/bash
echo "=== Финальная проверка системы мониторинга ==="
echo ""

# 1. Проверка сервисов
echo "1. Проверка сервисов..."
if docker-compose ps | grep -q "Up"; then
  echo "   ✓ Все сервисы запущены"
else
  echo "   ✗ Есть проблемы с сервисами"
  docker-compose ps
  exit 1
fi

# 2. Очистка старых метрик (опционально)
echo "2. Очистка старых данных..."
curl -s -X POST http://localhost:9090/-/flush > /dev/null
sleep 2

# 3. Запуск нагрузки
echo "3. Запуск нагрузочного теста (30 секунд)..."
echo "   Генерируем разнообразную нагрузку:"
echo "   - 60% успешных запросов"
echo "   - 30% запросов с ошибками"
echo "   - 10% медленных запросов"

timeout 30 bash -c '
REQUEST_COUNT=0
while true; do
  REQUEST_TYPE=$((RANDOM % 10))
  
  if [ $REQUEST_TYPE -lt 3 ]; then
    # 30% ошибок
    curl -s "http://localhost:8080/api/force-error" > /dev/null
    echo -n "E"
  elif [ $REQUEST_TYPE -lt 4 ]; then
    # 10% медленных запросов
    curl -s "http://localhost:8080/api/orders?delay=1500" > /dev/null
    echo -n "S"
  else
    # 60% успешных
    ENDPOINT=$((RANDOM % 3))
    case $ENDPOINT in
      0) curl -s "http://localhost:8080/api/orders" > /dev/null ;;
      1) curl -s "http://localhost:8080/api/products" > /dev/null ;;
      2) curl -s "http://localhost:8080/api/users" > /dev/null ;;
    esac
    echo -n "."
  fi
  
  REQUEST_COUNT=$((REQUEST_COUNT + 1))
  sleep 0.1
done' &
LOAD_PID=$!

# 4. Ожидание данных
echo -e "\n4. Ожидание сбора данных (40 секунд)..."
sleep 40

# 5. Проверка Prometheus
echo "5. Проверка Prometheus метрик..."
PROM_RESPONSE=$(curl -s "http://localhost:9090/api/v1/query?query=up{job=\"monitoring-app\"}")
if echo "$PROM_RESPONSE" | jq -e '.data.result[0]' > /dev/null 2>&1; then
  INSTANCE=$(echo "$PROM_RESPONSE" | jq -r '.data.result[0].metric.instance')
  VALUE=$(echo "$PROM_RESPONSE" | jq -r '.data.result[0].value[1]')
  echo "   ✓ Приложение мониторится: $INSTANCE = $VALUE"
else
  echo "   ✗ Приложение не найдено в метриках"
fi

# 6. Проверка HTTP метрик
echo "6. Проверка HTTP метрик:"
HTTP_DATA=$(curl -s "http://localhost:9090/api/v1/query?query=http_requests_total")
HTTP_COUNT=$(echo "$HTTP_DATA" | jq '.data.result | length // 0')
echo "   Всего записей http_requests_total: $HTTP_COUNT"

if [ "$HTTP_COUNT" -gt 0 ]; then
  echo "   Распределение по статусам:"
  echo "$HTTP_DATA" | jq -r '
    .data.result | 
    group_by(.metric.status) | 
    .[] | 
    "     Статус \(.[0].metric.status): \(length) запросов, последнее значение: \(.[0].value[1])"
  ' | sort -k2 -nr
fi

# 7. Проверка error rate (правильное выражение)
echo "7. Расчет error rate за 2 минуты:"
# Правильное выражение с защитой от деления на ноль
ERROR_RATE_QUERY="(sum(rate(http_requests_total{status=~\"5..\"}[2m])) / (sum(rate(http_requests_total[2m])) > 0)) * 100"
ERROR_RATE=$(curl -s "http://localhost:9090/api/v1/query?query=$(echo $ERROR_RATE_QUERY | jq -sRr @uri)")
ERROR_VALUE=$(echo "$ERROR_RATE" | jq -r '.data.result[0].value[1] // "0"')
echo "   Текущий error rate: ${ERROR_VALUE}%"
echo "   Порог для алерта: > 5%"

if (( $(echo "$ERROR_VALUE > 5" | bc -l 2>/dev/null || echo "0") )); then
  echo "   ⚠️  Превышен порог! Ожидаем срабатывание алерта"
else
  echo "   ✓ В пределах нормы"
fi

# 8. Проверка latency
echo "8. Проверка latency за 2 минуты:"
LATENCY_P95_QUERY="histogram_quantile(0.95, sum by(le) (rate(http_request_duration_seconds_bucket[2m])))"
LATENCY_P95=$(curl -s "http://localhost:9090/api/v1/query?query=$(echo $LATENCY_P95_QUERY | jq -sRr @uri)")
LATENCY_P95_VALUE=$(echo "$LATENCY_P95" | jq -r '.data.result[0].value[1] // "0"')
echo "   Текущий p95 latency: ${LATENCY_P95_VALUE}s"
echo "   Порог для алерта: > 0.5s"

LATENCY_P99_QUERY="histogram_quantile(0.99, sum by(le) (rate(http_request_duration_seconds_bucket[2m])))"
LATENCY_P99=$(curl -s "http://localhost:9090/api/v1/query?query=$(echo $LATENCY_P99_QUERY | jq -sRr @uri)")
LATENCY_P99_VALUE=$(echo "$LATENCY_P99" | jq -r '.data.result[0].value[1] // "0"')
echo "   Текущий p99 latency: ${LATENCY_P99_VALUE}s"
echo "   Порог для критического алерта: > 1s"

#9. Проверка алертов Grafana
9. Проверка алертов Grafana
9. Проверка алертов Grafana
echo "9. Проверка алертов Grafana:"
sleep 5

RULES_CONFIG=$(curl -s -u admin:admin "http://localhost:3000/api/v1/provisioning/alert-rules" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$RULES_CONFIG" ]; then
    echo "   ✗ Не удалось получить правила алертов"
    exit 1
fi

RULES_COUNT=$(echo "$RULES_CONFIG" | jq '. | length // 0' 2>/dev/null)
echo "   Всего правил: $RULES_COUNT"

if [ "$RULES_COUNT" -gt 0 ]; then
  echo "   Список загруженных правил:"
  
  # Читаем правила построчно, избегая проблем с парсингом
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [ -n "$line" ]; then
      echo "     - $line"
    fi
  done < <(echo "$RULES_CONFIG" | jq -r '.[] | "\(.title) (группа: \(.ruleGroup))"' 2>/dev/null)
  
  echo ""
  echo "   Статус: Правила успешно загружены"
  echo "   Для проверки состояний перейдите в интерфейс Grafana:"
  echo "   http://localhost:3000/alerting/list"
  
else
  echo "   ✗ Правила не загружены или отсутствуют"
fi


# 10. Проверка активных алертов
echo "10. Проверка активных алертов:"
ACTIVE=$(curl -s -u admin:admin http://localhost:3000/api/alertmanager/grafana/api/v2/alerts 2>/dev/null || echo "[]")
ACTIVE_COUNT=$(echo "$ACTIVE" | jq '. | length // 0')
echo "   Активных алертов: $ACTIVE_COUNT"

if [ "$ACTIVE_COUNT" -gt 0 ]; then
  echo "   Список активных алертов:"
  echo "$ACTIVE" | jq -r '.[] | "     - \(.labels.alertname) (\(.labels.severity)): \(.status.state) с \(.startsAt | fromdateiso8601 | strftime("%H:%M:%S"))"'
fi

# 11. Очистка
kill $LOAD_PID 2>/dev/null
wait $LOAD_PID 2>/dev/null

echo -e "\n=== Сводка результатов ==="
echo "✅ HTTP метрики: $HTTP_COUNT записей"
echo "✅ Error rate: ${ERROR_VALUE}% (порог: 5%)"
echo "✅ Latency P95: ${LATENCY_P95_VALUE}s (порог: 0.5s)"
echo "✅ Latency P99: ${LATENCY_P99_VALUE}s (порог: 1s)"
echo "✅ Правил Grafana: $RULES_COUNT"
echo "✅ Активных алертов: $ACTIVE_COUNT"

echo -e "\n=== Рекомендации ==="
if [ "$RULES_COUNT" -eq 0 ]; then
  echo "1. Правила не загружены. Проверьте конфигурацию."
elif [ "$ACTIVE_COUNT" -eq 0 ]; then
  echo "1. Алерты не сработали. Возможные причины:"
  echo "   - Недостаточно данных (нужно больше времени)"
  echo "   - Пороги слишком высокие"
  echo "   - Проблемы с выражениями в правилах"
  echo "2. Проверьте выражения в Prometheus:"
  echo "   Error Rate: $ERROR_RATE_QUERY"
  echo "   Latency P95: $LATENCY_P95_QUERY"
else
  echo "1. Алерты работают! Проверьте:"
  echo "   - http://localhost:3000/alerting/list"
  echo "   - http://localhost:9090/graph"
fi

echo -e "\n=== Проверка завершена ==="