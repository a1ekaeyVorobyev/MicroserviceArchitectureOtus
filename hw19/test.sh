#!/bin/bash

echo "🔄 Запускаем port-forward для сервисов..."

# Убить старые port-forward процессы
pkill -f "kubectl port-forward.*auth-service"
pkill -f "kubectl port-forward.*profile-service"

# Запустить port-forward для обоих сервисов
kubectl port-forward svc/auth-service 8081:80 -n arch-homework > /dev/null 2>&1 &
PF_AUTH=$!
kubectl port-forward svc/profile-service 8082:80 -n arch-homework > /dev/null 2>&1 &
PF_PROFILE=$!

echo "✅ auth-service на localhost:8081"
echo "✅ profile-service на localhost:8082"

# Ждем готовности
sleep 3

echo ""
echo "📝 Регистрируем пользователя..."
curl -s -X POST http://localhost:8081/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test123"}' | jq .

echo ""
echo "🔑 Логинимся..."
TOKEN=$(curl -s -X POST http://localhost:8081/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test123"}' | jq -r .access_token)

echo "Токен: $TOKEN"

echo ""
echo "👤 Обновляем профиль..."
curl -s -X PUT http://localhost:8082/profile/me \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"first_name":"Ivan","last_name":"Ivanov","phone":"12345"}' | jq .

echo ""
echo "👤 Получаем профиль..."
curl -s -X GET http://localhost:8082/profile/me \
  -H "Authorization: Bearer $TOKEN" | jq .

echo ""
echo "🧹 Очищаем port-forward..."
kill $PF_AUTH $PF_PROFILE 2>/dev/null

echo "✅ Готово!"