#!/bin/bash

echo -e "\033[1;34m========================================\033[0m"
echo -e "\033[1;32m    БЫСТРЫЙ ЗАПУСК ТЕСТОВ    \033[0m"
echo -e "\033[1;34m========================================\033[0m"

# Останавливаем старые процессы
pkill -f "kubectl port-forward" 2>/dev/null

# Запускаем port-forward
kubectl port-forward -n arch-homework service/user-service 8081:8080 > /dev/null 2>&1 &
kubectl port-forward -n arch-homework service/order-service 8082:8080 > /dev/null 2>&1 &
kubectl port-forward -n arch-homework service/billing-service 8083:8080 > /dev/null 2>&1 &
kubectl port-forward -n arch-homework service/notification-service 8084:8080 > /dev/null 2>&1 &

sleep 3

# Запускаем тесты
newman run testPostman/collection.json \
    --environment testPostman/env-local.json \
    --reporters cli,json \
    --reporter-json-export test-results.json

# Останавливаем port-forward
pkill -f "kubectl port-forward"