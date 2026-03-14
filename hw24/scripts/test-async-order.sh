#!/bin/bash

echo "========================================="
echo "  ТЕСТ АСИНХРОННЫХ НОТИФИКАЦИЙ В ORDER-SERVICE"
echo "========================================="

# Создаем пользователя
echo -e "\n1. Создание пользователя..."
USER_RESPONSE=$(curl -s -X POST http://localhost:8081/users \
  -H "Content-Type: application/json" \
  -d '{"email":"async@test.com"}')
USER_ID=$(echo $USER_RESPONSE | jq -r '.id')
echo "   User ID: $USER_ID"

# Пополняем счет
echo -e "\n2. Пополнение счета..."
curl -s -X POST http://localhost:8083/accounts/$USER_ID/deposit \
  -H "Content-Type: application/json" \
  -d '{"amount":200}' | jq .

# Создаем успешный заказ и замеряем время ответа
echo -e "\n3. Создание успешного заказа (асинхронное уведомление)..."
START_TIME=$(date +%s%N)
ORDER_RESPONSE=$(curl -s -X POST http://localhost:8082/orders \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"$USER_ID\",\"amount\":100,\"email\":\"async@test.com\"}")
END_TIME=$(date +%s%N)
RESPONSE_TIME=$(( ($END_TIME - $START_TIME) / 1000000 ))

echo "   Ответ получен через: ${RESPONSE_TIME}ms"
echo "   Ответ: $ORDER_RESPONSE" | jq .

# Сразу проверяем уведомления (они могут еще не успеть)
echo -e "\n4. Немедленная проверка уведомлений (возможно пусто)..."
sleep 0.1
curl -s "http://localhost:8084/notifications?user_id=$USER_ID" | jq .

# Ждем и проверяем снова
echo -e "\n5. Проверка через 500ms (уведомление должно быть в БД)..."
sleep 0.5
curl -s "http://localhost:8084/notifications?user_id=$USER_ID" | jq .

# Проверяем данные в PostgreSQL
echo -e "\n6. Проверка данных в PostgreSQL:"
kubectl exec -n arch-homework deployment/postgres-notification -- psql -U notification_user -d notifications -c "SELECT id, user_id, message, created_at FROM notifications ORDER BY created_at DESC LIMIT 2;"

# Создаем заказ с недостаточными средствами
echo -e "\n7. Создание заказа с недостаточными средствами..."
ORDER_RESPONSE2=$(curl -s -X POST http://localhost:8082/orders \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"$USER_ID\",\"amount\":200,\"email\":\"async@test.com\"}")
echo "   Ответ: $ORDER_RESPONSE2" | jq .

sleep 0.5
echo -e "\n8. Проверка уведомлений (должно быть 2):"
curl -s "http://localhost:8084/notifications?user_id=$USER_ID" | jq .

echo -e "\n✅ Тест завершен!"
