#!/bin/bash

echo "=================================="
echo "🔧 ЗАПУСК ТЕСТИРОВАНИЯ СЕРВИСОВ"
echo "=================================="

# Убиваем старые процессы port-forward
pkill -f "kubectl port-forward" 2>/dev/null

# Запускаем port-forward для всех сервисов
echo "🚀 Запуск port-forward..."
kubectl port-forward -n arch-homework service/user-service 8081:8080 > /dev/null 2>&1 &
kubectl port-forward -n arch-homework service/order-service 8082:8080 > /dev/null 2>&1 &
kubectl port-forward -n arch-homework service/billing-service 8083:8080 > /dev/null 2>&1 &
kubectl port-forward -n arch-homework service/notification-service 8084:8080 > /dev/null 2>&1 &

sleep 3

echo "✅ Port-forward запущен"
echo ""

echo "=== ТЕСТ 1: User Service ==="
echo -n "Health check: "
curl -s http://localhost:8081/health | jq .
echo -n "GET /users (начальный): "
curl -s http://localhost:8081/users | jq .
echo -n "POST /users: "
curl -s -X POST http://localhost:8081/users \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}' | jq .
echo -n "GET /users (после POST): "
curl -s http://localhost:8081/users | jq .
echo ""

echo "=== ТЕСТ 2: Order Service ==="
echo -n "Health check: "
curl -s http://localhost:8082/health | jq .
echo ""

echo "=== ТЕСТ 3: Billing Service ==="
echo -n "Health check: "
curl -s http://localhost:8083/health | jq .
echo ""

echo "=== ТЕСТ 4: Notification Service ==="
echo -n "Health check: "
curl -s http://localhost:8084/health | jq .
echo ""

echo "=================================="
echo "✅ Все тесты завершены"
echo "=================================="
echo ""
echo "Для остановки port-forward выполните:"
echo "pkill -f 'kubectl port-forward'"
