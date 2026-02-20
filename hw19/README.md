# Arch Homework – Production Ready Version

add /etc/host
127.0.0.1 arch.homework

## Overview

Production-ready Go application deployed to Kubernetes.

Includes:

- auth-service (JWT + Refresh Token via Redis)
- profile-service (isolated profile access)
- PostgreSQL
- Redis
- Helm chart
- Rate limiting (NGINX Ingress)
- DockerHub-ready images
- Migrations
- Makefile automation
- Postman + Newman tests support

---

# Architecture

Client → NGINX Ingress →
  - /auth → auth-service
  - /profile → profile-service

auth-service:
- Registers users
- Issues JWT access token (15 min)
- Stores refresh token in Redis (7 days)

profile-service:
- Validates JWT
- Extracts user_id
- Allows access only to own profile

PostgreSQL:
- users table
- profiles table

Redis:
- refresh token storage

---

# Namespace

All Kubernetes resources are deployed into:

arch-homework

---

# Local Development

## 1. Build images

make build

## 2. Push images

make push

# Docker Compose (Local Run)

docker-compose up --build

Services:
- auth-service → localhost:8081
- profile-service → localhost:8082
- postgres → localhost:5432
- redis → localhost:6379

---

# Kubernetes Deployment

## 1. Create namespace

kubectl create namespace arch-homework

## 2. Deploy with Helm

make deploy

Or manually:

helm upgrade --install arch-app ./helm -n arch-homework

---

# Ingress

Host:

arch.homework

Add to /etc/hosts:

127.0.0.1 arch.homework

---

# Rate Limiting

Ingress annotations:

nginx.ingress.kubernetes.io/limit-rps: "10"
nginx.ingress.kubernetes.io/limit-burst-multiplier: "3"

This limits each IP to 10 requests/sec.

---

# Migrations

Located in:

migrations/001_init.sql

Creates:

users
profiles

---

# API Endpoints

POST /auth/register
POST /auth/login
POST /auth/refresh

GET /profile/me
PUT /profile/me

Authorization header:

Bearer <access_token>

---

# Running Tests (Newman)

make test

Uses:

{{baseUrl}} = http://arch.homework

---

# Security Notes

- Passwords hashed with bcrypt
- Access token short-lived (15 min)
- Refresh token stored in Redis
- Profile access strictly bound to JWT user_id
- Rate limiting enabled
- Services isolated

---

