# Users Service — RESTful CRUD (Kubernetes)

## Описание

Данный проект представляет собой микросервис `Users Service`, реализующий RESTful CRUD API
для управления пользователями.

Сервис развёртывается в Kubernetes, использует отдельную базу данных и следует
инфраструктурным best practices:
- Database per Service
- ConfigMap для конфигурации
- Secret для хранения чувствительных данных
- Kubernetes Job для миграций
- Ingress для внешнего доступа
- Helm chart для шаблонизации ресурсов

---

## Реализованный функционал

### REST API

| Метод | URL | Описание |
|-----|-----|---------|
| POST | `/users` | Создание пользователя |
| GET | `/users/{id}` | Получение пользователя |
| PUT | `/users/{id}` | Обновление пользователя |
| DELETE | `/users/{id}` | Удаление пользователя |

Формат данных: JSON

---

## Архитектура

Ingress (arch.homework)
|
Service
|
Deployment (users-service)
|
PostgreSQL (users-db)


Каждый микросервис использует собственную базу данных.
Связи между микросервисами реализуются на уровне API, без foreign keys между БД.

## Структура базы данных

### ER-диаграмма

Основные сущности:
- `users`
- `user_profiles`

Связь: 1 к 1

Первичные ключи:
- `users.id`
- `user_profiles.user_id`

Ограничения:
- `users.email` — UNIQUE
- NOT NULL на обязательных полях

ER-диаграмма представлена в каталоге `docs/` (PlantUML / PNG).

---

## DDL (PostgreSQL)

```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE user_profiles (
    user_id BIGINT PRIMARY KEY,
    bio TEXT,
    CONSTRAINT fk_user_profiles_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);
````

---

## Kubernetes конфигурация

### Используемые ресурсы

* ConfigMap — параметры подключения к БД
* Secret — логин и пароль БД
* Deployment — приложение
* Service — доступ внутри кластера
* Ingress — доступ извне (`arch.homework`)
* Job — первоначальные миграции БД

---

## Установка базы данных (Helm)

Используется PostgreSQL (Bitnami chart).

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install postgres bitnami/postgresql -f values.yaml
```

`values.yaml` содержит настройки пользователя и базы данных.

---

## Миграции БД

Миграции выполняются с помощью Kubernetes Job:

```bash
kubectl apply -f job-migrations.yaml
```

Job выполняется до запуска основного приложения.

---

## Установка приложения (Helm)

```bash
helm install users ./helm/users-service
```

Удаление:

```bash
helm uninstall users
```

---

## Проверка работы API

Для проверки используется Postman коллекция, расположенная в репозитории.

Базовый URL:

```
http://arch.homework
```

### Newman

```bash
newman run users.postman_collection.json
```

Результат выполнения Newman приложен в виде скриншота/вывода команды.

---

## Структура репозитория

```
.
├── helm/
│   └── users-service/
├── k8s/
├── migrations/
├── docs/
│   └── er-diagram.puml
├── postman/
│   └── users.postman_collection.json
└── README.md
```

---

## Используемые технологии

* Kubernetes
* Helm
* PostgreSQL
* REST
* Postman / Newman

---

## Соответствие требованиям задания

* RESTful CRUD API — ✔
* Использование БД — ✔
* ConfigMap для конфигурации — ✔
* Secrets для доступов — ✔
* Миграции через Job — ✔
* Ingress с доменом `arch.homework` — ✔
* Helm chart (задание со ⭐) — ✔

