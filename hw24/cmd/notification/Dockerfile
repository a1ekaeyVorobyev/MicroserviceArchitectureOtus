FROM golang:1.21-alpine AS builder

# Устанавливаем зависимости для сборки с PostgreSQL
RUN apk add --no-cache git gcc musl-dev

WORKDIR /app
COPY . .

# Скачиваем зависимости
RUN go mod init notification-service 2>/dev/null || true
RUN go get github.com/lib/pq
RUN go mod tidy

# Сборка приложения
RUN go build -o app main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates postgresql-client

WORKDIR /root/
COPY --from=builder /app/app .

EXPOSE 8080
CMD ["./app"]