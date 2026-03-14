#!/bin/bash

# Получить порты сервисов
USER_PORT=$(kubectl get svc user-service -n arch-homework -o jsonpath='{.spec.ports[0].nodePort}')
ORDER_PORT=$(kubectl get svc order-service -n arch-homework -o jsonpath='{.spec.ports[0].nodePort}')
BILLING_PORT=$(kubectl get svc billing-service -n arch-homework -o jsonpath='{.spec.ports[0].nodePort}')
NOTIFICATION_PORT=$(kubectl get svc notification-service -n arch-homework -o jsonpath='{.spec.ports[0].nodePort}')

echo "User port: $USER_PORT"
echo "Order port: $ORDER_PORT"
echo "Billing port: $BILLING_PORT"
echo "Notification port: $NOTIFICATION_PORT"

# Обновить environment файл
sed -i "s/192.168.58.2:[0-9]*/192.168.58.2:$USER_PORT/g" postman/env-nodeport.json
sed -i "s/192.168.58.2:[0-9]*/192.168.58.2:$ORDER_PORT/g" postman/env-nodeport.json
sed -i "s/192.168.58.2:[0-9]*/192.168.58.2:$BILLING_PORT/g" postman/env-nodeport.json
sed -i "s/192.168.58.2:[0-9]*/192.168.58.2:$NOTIFICATION_PORT/g" postman/env-nodeport.json

echo "Environment file updated with current ports"