#!/bin/bash

echo "🚀 Starting API Load Test"
echo "========================"

BASE_URL="http://localhost:8080"
ENDPOINTS=("/api/users" "/api/orders" "/api/products" "/api/force-error")
CONCURRENT_USERS=20
DURATION=60  # Уменьшим до 1 минуты для теста
REQUESTS_PER_SECOND=50

echo "Configuration:"
echo "- Base URL: $BASE_URL"
echo "- Concurrent users: $CONCURRENT_USERS"
echo "- Duration: ${DURATION}s"
echo "- Target RPS: $REQUESTS_PER_SECOND"
echo ""

# Функция для генерации запросов (без bc)
generate_request() {
    local endpoint=${ENDPOINTS[$RANDOM % ${#ENDPOINTS[@]}]}
    local url="$BASE_URL$endpoint"

    # Добавляем параметры для тестирования
    local random=$((RANDOM % 100))

    if [ $random -lt 70 ]; then
        # 70% - нормальные запросы
        :
    elif [ $random -lt 85 ]; then
        # 15% - запросы с задержкой
        delay=$((100 + RANDOM % 2000))
        url="$url?delay=$delay"
    elif [ $random -lt 95 ]; then
        # 10% - запросы с ошибками
        url="$url?error=true"
    else
        # 5% - медленные запросы
        delay=$((2000 + RANDOM % 5000))
        url="$url?delay=$delay"
    fi

    # Отправляем запрос
    start_time=$(date +%s%N)  # наносекунды
    response=$(curl -s -w "%{http_code}" -o /dev/null "$url")
    end_time=$(date +%s%N)

    # Вычисляем длительность в секундах (без bc)
    duration_ms=$(( (end_time - start_time) / 1000000 ))  # переводим в миллисекунды
    duration_seconds=$(echo "scale=3; $duration_ms / 1000" | awk '{printf "%.3f", $1}')

    # Логируем медленные запросы (>1 секунды)
    if [ $duration_ms -gt 1000 ]; then
        echo "[SLOW] $url - ${duration_seconds}s - Status: $response" >> load_test.log
    fi

    # Логируем ошибки
    if [ "$response" -ge 500 ]; then
        echo "[ERROR] $url - Status: $response" >> load_test.log
    fi
}

# Очищаем лог
> load_test.log

echo "Starting load test at $(date)"
echo "Press Ctrl+C to stop early"
echo ""

# Запускаем нагрузку
for ((i=1; i<=DURATION; i++)); do
    echo -ne "Elapsed: ${i}s / ${DURATION}s\r"

    # Запускаем concurrent запросов
    for ((j=0; j<CONCURRENT_USERS; j++)); do
        generate_request &
    done

    # Ждем 1 секунду
    sleep 1

    # Ограничиваем количество фоновых процессов
    wait
done

echo ""
echo ""
echo "📊 Load Test Summary"
echo "==================="
echo "Total duration: ${DURATION}s"
echo ""

# Анализируем лог
if [ -f load_test.log ]; then
    total_errors=$(grep -c "\[ERROR\]" load_test.log)
    total_slow=$(grep -c "\[SLOW\]" load_test.log)

    echo "Total errors (5xx): $total_errors"
    echo "Total slow requests (>1s): $total_slow"
    echo ""

    if [ $total_errors -gt 0 ]; then
        echo "Top error endpoints:"
        grep "\[ERROR\]" load_test.log | cut -d' ' -f2 | sort | uniq -c | sort -rn | head -5
        echo ""
    fi

    if [ $total_slow -gt 0 ]; then
        echo "Top slow endpoints:"
        grep "\[SLOW\]" load_test.log | cut -d' ' -f2 | sort | uniq -c | sort -rn | head -5
        echo ""
    fi
fi

echo "Load test completed at $(date)"
echo "Check Grafana dashboard: http://localhost:3000"