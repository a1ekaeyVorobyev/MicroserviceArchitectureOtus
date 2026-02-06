APP_NAME=user-service
IMAGE_NAME=a1ekseyramblerru/monitoring-app
TAG=1.0
.PHONY: build up down logs clean test restart

build:
	@echo "Building Docker images..."
	docker-compose build

up:
	@echo "Starting services..."
	docker-compose up -d

down:
	@echo "Stopping services..."
	docker-compose down

logs:
	@echo "Showing logs..."
	docker-compose logs -f

clean:
	@echo "Cleaning up..."
	docker-compose down -v
	docker system prune -f

test-app:
	@echo "Testing application..."
	curl http://localhost:8080/health
	@echo ""
	curl http://localhost:8080/api/users

test-metrics:
	@echo "Testing metrics endpoint..."
	curl http://localhost:8080/metrics | grep http_requests_total

test1:
	@echo "Running load test..."
	./test/final_test.sh

test2:
	@echo "Running load test..."
	./test/test-alerts-final.sh


restart: down up
	@echo "Services restarted"

docker-build:
	    docker build -t $(IMAGE_NAME):$(TAG) .

docker-push:
	    docker push $(IMAGE_NAME):$(TAG)

status:
	@echo "=== Service Status ==="
	@docker-compose ps
	@echo ""
	@echo "=== URLs ==="
	@echo "App:        http://localhost:8080"
	@echo "Prometheus: http://localhost:9090"
	@echo "Grafana:    http://localhost:3000"