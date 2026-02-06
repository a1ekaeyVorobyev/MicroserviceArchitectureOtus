#!/bin/bash
echo "=== Финальный тест системы алертинга ==="

# 1. Запустите нагрузку
echo "1. Запуск нагрузочного теста..."
./load-test.sh > /dev/null 2>&1 &
LOAD_PID=$!

# 2. Ждем метрик
echo "2. Ожидание метрик..."
sleep 30

# 3. Проверка Prometheus (с обработкой ошибок)
echo "3. Проверка Prometheus..."
PROM_RESPONSE=$(curl -s "http://localhost:9090/api/v1/series?match[]={job=\"monitoring-app\"}")
METRIC_COUNT=$(echo "$PROM_RESPONSE" | jq -r '.data | length // 0')
echo "   Метрик приложения: $METRIC_COUNT"

# Дополнительная проверка
echo "   Примеры метрик:"
echo "$PROM_RESPONSE" | jq -r '.data[0:3][]? | .__name__' | while read metric; do
  echo "     - $metric"
done

# 4. Проверка Grafana
echo "4. Проверка Grafana..."
RULES_RESPONSE=$(curl -s -u admin:admin http://localhost:3000/api/v1/provisioning/alert-rules)
RULES_COUNT=$(echo "$RULES_RESPONSE" | jq -r '. | length // 0')
echo "   Правил: $RULES_COUNT"

if [ "$RULES_COUNT" -gt 0 ]; then
  echo "   Список правил:"
  echo "$RULES_RESPONSE" | jq -r '.[]? | .title' | while read title; do
    echo "     - $title"
  done
fi

# 5. Проверка активных алертов
echo "5. Проверка активных алертов..."
ACTIVE_ALERTS=$(curl -s -u admin:admin http://localhost:3000/api/alertmanager/grafana/api/v2/alerts)
ACTIVE_COUNT=$(echo "$ACTIVE_ALERTS" | jq -r '. | length // 0')
echo "   Активных алертов: $ACTIVE_COUNT"

# 6. Проверка конкретных метрик
echo "6. Проверка HTTP метрик:"
for metric in "http_requests_total" "http_request_duration_seconds_bucket"; do
  COUNT=$(curl -s "http://localhost:9090/api/v1/series?match[]=${metric}{job=\"monitoring-app\"}" | jq -r '.data | length // 0')
  echo "   $metric: $COUNT серий"
done

# 7. Проверка значений
echo "7. Проверка значений метрик:"
echo "   Последние запросы:"
curl -s "http://localhost:9090/api/v1/query?query=http_requests_total" | \
  jq -r '.data.result[0:3][]? | "     \(.metric) = \(.value[1])"' 2>/dev/null || echo "     Нет данных"

# 8. Остановка нагрузки
kill $LOAD_PID 2>/dev/null
wait $LOAD_PID 2>/dev/null

echo -e "\n=== Сводка ==="
echo "Метрик в Prometheus: $METRIC_COUNT"
echo "Правил в Grafana: $RULES_COUNT"
echo "Активных алертов: $ACTIVE_COUNT"

if [ "$METRIC_COUNT" -eq 0 ]; then
  echo "⚠️  Внимание: Prometheus не нашел метрик приложения!"
  echo "   Проверьте:"
  echo "   1. Конфигурацию Prometheus: cat prometheus/prometheus.yml"
  echo "   2. Targets Prometheus: curl http://localhost:9090/api/v1/targets"
  echo "   3. Метрики приложения: curl http://localhost:8080/metrics | head -5"
fi

if [ "$RULES_COUNT" -eq 0 ]; then
  echo "⚠️  Внимание: В Grafana нет правил алертов!"
  echo "   Проверьте файл: ./grafana/provisioning/alerting/alert-rules.yml"
fi

echo -e "\n=== Тест завершен ==="
