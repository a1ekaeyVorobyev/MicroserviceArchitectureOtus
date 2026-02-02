# Health Service (Go)

Минимальный HTTP сервис для Kubernetes.

## Функциональность
- GET /health
- Ответ:
```json
{"status":"OK"}

##Запуск
1. minikube start
2. make k8s-apply
3. Узнаём URL для сервиса
minikube service health-service --url

запуск и проверка через deplay.sh