#!/bin/bash

echo "========================================="
echo "    ДИАГНОСТИКА ORDER SERVICE"
echo "========================================="

# Получаем информацию о поде
POD_NAME=$(kubectl get pods -n arch-homework -l app=order-service -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $POD_NAME"
echo ""

# Проверяем статус пода
echo "--- Статус пода ---"
kubectl get pod $POD_NAME -n arch-homework
echo ""

# Проверяем логи
echo "--- Последние 20 строк логов ---"
kubectl logs $POD_NAME -n arch-homework --tail=20
echo ""

# Запускаем port-forward
echo "--- Запуск port-forward ---"
kubectl port-forward -n arch-homework service/order-service 8082:8080 &
PF_PID=$!
sleep 3
echo ""

# Проверяем эндпоинты
echo "--- Тестирование эндпоинтов ---"
echo "GET /health:"
curl -s http://localhost:8082/health | jq .

echo -e "\nGET /orders (пустой список):"
curl -s http://localhost:8082/orders | jq .

echo -e "\nPOST /orders (создание заказа):"
curl -s -X POST http://localhost:8082/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id":"25","amount":50,"email":"test@example.com"}' -w "\nHTTP Status: %{http_code}\n" | jq .

echo -e "\nGET /orders (после создания):"
curl -s http://localhost:8082/orders | jq .

# Останавливаем port-forward
kill $PF_PID 2>/dev/null
echo ""
echo "========================================="
