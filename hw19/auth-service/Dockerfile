# Multi-stage build for production image
FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY . .
RUN go mod tidy
RUN go build -o auth-service


# Копируем миграции
COPY migrations ./migrations

FROM alpine:3.18
WORKDIR /app
COPY --from=builder /app/auth-service .
COPY --from=builder /app/migrations ./migrations
EXPOSE 8080
CMD ["./auth-service"]
