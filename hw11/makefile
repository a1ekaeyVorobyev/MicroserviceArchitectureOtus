APP_NAME=health-service-go
IMAGE_NAME=a1ekseyramblerru/health-service-go
TAG=1.0

.PHONY: build run docker-build docker-push k8s-apply k8s-delete

build:
	go build -o app

run:
	go run main.go

docker-build:
	docker build -t $(IMAGE_NAME):$(TAG) .

docker-push:
	docker push $(IMAGE_NAME):$(TAG)

k8s-apply:
	kubectl apply -f k8s/

k8s-delete:
	kubectl delete -f k8s/
