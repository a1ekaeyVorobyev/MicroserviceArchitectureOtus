API App (Go) → Prometheus (метрики) → Grafana (визуализация + алертинг)

text

## Запуск

### 1. Запуск приложения
```bash
# Установите Go модули
export GO111MODULE=on
go mod init monitoring-app
go mod tidy

# Запустите приложение
go run main.go
Приложение будет доступно на http://localhost:8080

2. Запуск стека мониторинга
bash
# Запустите Prometheus и Grafana
docker-compose up -d
Сервисы:

Prometheus: http://localhost:9090

Grafana: http://localhost:3000 (admin/admin)

3. Настройка Grafana
Войдите в Grafana (admin/admin)

Импортируйте дашборд из файла grafana/dashboard.json

Настройте алертинг через UI Grafana

Дашборд
Дашборд содержит следующие панели:

Основные метрики:
Overall RPS - запросы в секунду по эндпоинтам

Error Rate - процент ошибок 5xx

Latency by Quantiles - p50, p95, p99 задержки

Max Latency - максимальное время ответа

Ingress-like метрики:
Ingress Latency - метрики в стиле nginx-ingress

Status Codes Distribution - распределение HTTP статусов

Дополнительно:
Active Requests - активные запросы в реальном времени

Top Endpoints by Errors - таблица с топом ошибок

Алертинг
Настроены следующие алерты:

Error Rate:
Critical: >5% ошибок в течение 2 минут

Latency:
Warning: p95 > 1 секунды в течение 2 минут

Critical: p99 > 2 секунд в течение 1 минуты

Availability:
Critical: Нет трафика в течение 5 минут

Тестирование
Генерация нагрузки:
bash
./load-test.sh
Ручное тестирование:
bash
# Ошибки
curl "http://localhost:8080/api/force-error"
curl "http://localhost:8080/api/users?error=true"

# Задержки
curl "http://localhost:8080/api/orders?delay=2000"
curl "http://localhost:8080/api/slow?delay=5000"

# Нагрузочное тестирование
curl "http://localhost:8080/api/load?requests=1000&concurrent=50"
Метрики
Приложение экспортирует следующие метрики:

Основные:
http_requests_total - общее количество запросов

http_request_duration_histogram_seconds - гистограмма времени ответа

http_errors_total - ошибки 5xx

http_requests_in_progress - активные запросы

Ingress-like:
ingress_http_requests_total - метрики в стиле nginx-ingress

ingress_http_response_duration_seconds - время ответа ingress

Настройка алертов в Grafana UI
Перейдите в Alerting → Contact points

Создайте contact point (email, Slack, etc.)

Перейдите в Alert rules

Создайте правило:

Query: sum(rate(http_errors_total[5m])) / sum(rate(http_requests_total[5m])) * 100

Condition: WHEN last() OF query(A, 5m, now) IS ABOVE 5

Configure notifications

text

## Инструкция по развертыванию:

1. **Создайте структуру проекта:**
```bash
mkdir -p monitoring-app/{prometheus,grafana/provisioning/{datasources,dashboards},static}
Создайте все файлы в соответствующих директориях

Дайте права на выполнение скрипта:

bash
chmod +x load-test.sh
Запустите приложение и стек мониторинга

Настройте алертинг в Grafana UI через раздел Alerting

Это решение предоставляет полный стек мониторинга с детальными метриками по API, разбивкой по эндпоинтам, квантилями задержек и настраиваемым алертингом.