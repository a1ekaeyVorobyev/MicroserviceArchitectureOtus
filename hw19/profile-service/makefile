APP_NAME=prifile-service
IMAGE_NAME=a1ekseyramblerru/profile-service
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

dc_up:
	docker-compose up --build
dc_down:
	docker-compose down