#!/bin/bash

echo "=== Генерация реалистичной нагрузки ==="
echo "Имитация поведения реального приложения"
echo "Нажмите Ctrl+C для остановки"
echo ""

TOTAL_REQUESTS=0
ERROR_REQUESTS=0
SLOW_REQUESTS=0

echo "📊 Начальные метрики:"
echo "  Время начала: $(date)"
echo ""

while true; do
  # Случайное распределение запросов
  REQUEST_TYPE=$((RANDOM % 100))
  
  if [ $REQUEST_TYPE -lt 5 ]; then
    # 5% - ошибки
    curl -s "http://localhost:8080/api/force-error" > /dev/null
    ERROR_REQUESTS=$((ERROR_REQUESTS + 1))
    echo -n "E"
  elif [ $REQUEST_TYPE -lt 10 ]; then
    # 5% - медленные запросы (1-3 секунды)
    DELAY=$((1 + RANDOM % 3))
    curl -s "http://localhost:8080/api/orders?delay=${DELAY}000" > /dev/null
    SLOW_REQUESTS=$((SLOW_REQUESTS + 1))
    echo -n "S"
  else
    # 90% - нормальные запросы
    ENDPOINT=$((RANDOM % 3))
    case $ENDPOINT in
      0) curl -s "http://localhost:8080/api/orders" > /dev/null ;;
      1) curl -s "http://localhost:8080/api/products" > /dev/null ;;
      2) curl -s "http://localhost:8080/api/users" > /dev/null ;;
    esac
    echo -n "."
  fi
  
  TOTAL_REQUESTS=$((TOTAL_REQUESTS + 1))
  
  # Каждые 50 запросов показываем статистику
  if [ $((TOTAL_REQUESTS % 50)) -eq 0 ]; then
    ERROR_RATE=$((ERROR_REQUESTS * 100 / TOTAL_REQUESTS))
    SLOW_RATE=$((SLOW_REQUESTS * 100 / TOTAL_REQUESTS))
    echo ""
    echo "  Запросов: $TOTAL_REQUESTS | Ошибок: $ERROR_REQUESTS ($ERROR_RATE%) | Медленных: $SLOW_REQUESTS ($SLOW_RATE%)"
  fi
  
  # Случайная задержка между запросами (0.1-0.5 секунды)
  SLEEP_TIME=$(echo "scale=2; 0.1 + 0.4 * $RANDOM / 32767" | bc)
  sleep $SLEEP_TIME
done