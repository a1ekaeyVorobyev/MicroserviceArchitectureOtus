# ==============================
# MAKEFILE FOR FULL WORKFLOW
# ==============================

DOCKER_USER=a1ekseyramblerru
NAMESPACE=arch-homework
RELEASE=arch-app
TAG=latest

build:
	docker build -t $(DOCKER_USER)/auth-service:latest ./auth-service
	docker build -t $(DOCKER_USER)/profile-service:latest ./profile-service
	docker build -t $(DOCKER_USER)/api-gateway:latest ./api-gateway

push:
	docker push $(DOCKER_USER)/auth-service:$(TAG)
	docker push $(DOCKER_USER)/profile-service:$(TAG)
	docker push $(DOCKER_USER)/api-gateway:$(TAG)

deploy:
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install $(RELEASE) ./helm -n $(NAMESPACE)

run:
	helm upgrade --install $(RELEASE) ./helm -n $(NAMESPACE)



delete_OLD:
	helm uninstall $(RELEASE) -n $(NAMESPACE)

delete:

# Удалить оставшийся сервис
	kubectl delete svc auth-service -n $(NAMESPACE)

# Удалить все deployment'ы (они создают поды)
	kubectl delete deployment --all -n $(NAMESPACE)

# Проверить, что все чисто
	kubectl get all -n $(NAMESPACE)



purge:
	helm uninstall $(RELEASE) -n $(NAMESPACE) || true
	kubectl delete all --all -n $(NAMESPACE)
	kubectl delete svc --all -n $(NAMESPACE) || true
	kubectl delete pvc --all -n $(NAMESPACE) || true
	kubectl delete configmap --all -n $(NAMESPACE) || true
	kubectl delete secret --all -n $(NAMESPACE) || true
# Или даже удалить весь namespace
wipe:
	kubectl delete namespace $(NAMESPACE)

# Тестирование через port-forward (рекомендуется)
test-local:
	 kubectl port-forward svc/api-gateway 8081:8080 -n $(NAMESPACE) & \
	 sleep 3 && \
	 newman run postman/collection.json --env-var baseUrl=http://localhost:8081 --reporters cli; \
	 pkill -f "kubectl port-forward"

# Тестирование через arch.homework (требует minikube tunnel)
test:
	   newman run postman/collection.json \
  --env-var baseUrl=http://arch.homework \
  --reporters cli

# Тестирование с кастомным URL
test-custom:
	 newman run postman/collection.json --env-var baseUrl=$(URL) --reporters cli

# Проброс порта gateway
port-forward:
	 kubectl port-forward svc/api-gateway 8081:8080 -n $(NAMESPACE)

# Все тесты сразу (с очисткой)
test-all: purge deploy port-forward test-local
