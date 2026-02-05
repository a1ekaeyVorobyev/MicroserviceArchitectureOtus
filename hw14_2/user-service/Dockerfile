# Stage 1: Build
FROM golang:1.25-alpine AS build

WORKDIR /app

# Модули Go
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o users-service main.go

# Stage 2: Runtime
FROM alpine:3.18
WORKDIR /app
COPY --from=build /app/users-service .
COPY migrations ./migrations

EXPOSE 8080
CMD ["./users-service"]
