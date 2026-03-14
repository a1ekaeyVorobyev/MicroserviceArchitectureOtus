#!/bin/bash

echo "==================================="
echo "ДИАГНОСТИКА ORDER SERVICE"
echo "==================================="

# Получаем имя пода
POD_NAME=$(kubectl get pod -n arch-homework -l app=order-service -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $POD_NAME"
echo ""

# Проверяем логи
echo "--- Последние 20 строк логов ---"
kubectl logs -n arch-homework $POD_NAME --tail=20
echo ""

# Запускаем port-forward
echo "--- Запуск port-forward ---"
kubectl port-forward -n arch-homework $POD_NAME 8082:8080 &
PF_PID=$!
sleep 3
echo ""

# Тестируем эндпоинты
echo "--- Тестирование эндпоинтов ---"
echo "GET /health:"
curl -s http://localhost:8082/health
echo -e "\n"

echo "GET /orders:"
curl -s http://localhost:8082/orders
echo -e "\n"

echo "POST /orders (должен вернуть 201):"
curl -s -X POST http://localhost:8082/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id":"16","amount":50,"email":"test@example.com"}' \
  -w "\nHTTP Status: %{http_code}\n"
echo ""

# Останавливаем port-forward
kill $PF_PID 2>/dev/null

echo "==================================="
