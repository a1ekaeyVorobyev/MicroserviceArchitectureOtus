# ./cmd/user/Dockerfile
FROM golang:1.26-alpine AS builder
WORKDIR /app
COPY . .
RUN go mod init order-service 2>/dev/null || true
RUN go mod tidy
RUN go build -o app main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/app .
EXPOSE 8080
CMD ["./app"]