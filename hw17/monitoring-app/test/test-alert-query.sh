#!/bin/bash

echo "=== Тестирование запросов алертов ==="

# 1. Тест запроса error rate
echo "1. Тест запроса Error Rate:"
QUERY='sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100'
echo "   Запрос: $QUERY"
curl -s "http://localhost:9090/api/v1/query?query=$QUERY" | \
  jq -r '.data.result[0] | "   Результат: \(.value[1])"' 2>/dev/null || echo "   ✗ Нет данных"

# 2. Тест запроса latency
echo -e "\n2. Тест запроса Latency:"
QUERY2='histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))'
echo "   Запрос: $QUERY2"
curl -s "http://localhost:9090/api/v1/query?query=$QUERY2" | \
  jq -r '.data.result[0] | "   Результат: \(.value[1]) секунд"' 2>/dev/null || echo "   ✗ Нет данных"

# 3. Проверка существования метрик
echo -e "\n3. Проверка метрик:"
for metric in "http_requests_total" "http_request_duration_seconds_bucket"; do
  COUNT=$(curl -s "http://localhost:9090/api/v1/series?match[]=$metric" | jq '.data | length')
  echo "   $metric: $COUNT серий"
done

# 4. Проверка лейблов
echo -e "\n4. Лейблы метрик:"
for metric in "http_requests_total" "http_request_duration_seconds_bucket"; do
  echo "   $metric:"
  curl -s "http://localhost:9090/api/v1/series?match[]=$metric" | \
    jq -r '.data[0] | to_entries[] | "     \(.key)=\(.value)"' 2>/dev/null | head -5 || echo "     Нет данных"
done
