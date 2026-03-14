# Arch Homework Microservices

АРХИТЕКТУРНОЕ РЕШЕНИЕ
Выбранный паттерн: Гибридный (HTTP + асинхронные нотификации)

Компоненты системы

Компонент	Назначение	Порт	Технологии
User Service	Управление пользователями	8081	Go, In-memory
Order Service	Обработка заказов	8082	Go, In-memory
Billing Service	Управление счетами	8083	Go, In-memory
Notification Service	Хранение уведомлений	8084	Go, PostgreSQL
PostgreSQL	База данных уведомлений	5432	PostgreSQL 15

🔌 API Endpoints

User Service (порт 8081)
POST /users - создание пользователя

GET /users - список пользователей

GET /health - проверка здоровья

Order Service (порт 8082)
POST /orders - создание заказа

GET /orders - список заказов

GET /health - проверка здоровья

Billing Service (порт 8083)
POST /accounts - создание счета

POST /accounts/{id}/deposit - пополнение счета

POST /accounts/{id}/withdraw - снятие средств

GET /accounts/{id} - получение баланса

GET /health - проверка здоровья

Notification Service (порт 8084)
POST /notifications - сохранение уведомления

GET /notifications?user_id={id} - получение уведомлений

GET /health - проверка здоровья

GET /test-db - тест подключения к БД


📊 Модели данных

sql
-- PostgreSQL схема
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'sent'
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
json
// Пример уведомления
{
  "id": 71,
  "user_id": "33",
  "email": "final_test@example.com",
  "message": "Заказ 64 успешно оформлен! Спасибо за покупку!",
  "created_at": "2026-03-14T10:46:31.74726Z",
  "status": "sent"
}
🚀 Инфраструктура развертывания
yaml

# Kubernetes (Minikube)
- Namespace: arch-homework
- Deployments: user-service, order-service, billing-service, notification-service, postgres
- Services: ClusterIP для каждого сервиса
- ConfigMap: postgres-init-sql (инициализация БД)
- Хранение: emptyDir (для простоты) или PersistentVolume (для продакшна)
✅ Преимущества выбранного подхода
Синхронное списание средств - гарантирует атомарность операции

Асинхронные уведомления - не задерживают ответ клиенту

PostgreSQL для нотификаций - надежное хранение с возможностью масштабирования

In-memory для остальных сервисов - высокая производительность

Микросервисная архитектура - независимое развертывание и масштабирование

📈 Метрики производительности
Среднее время ответа: 28ms

Максимальное время ответа: 79ms

Успешность тестов: 100%

Количество уведомлений в БД: > 70