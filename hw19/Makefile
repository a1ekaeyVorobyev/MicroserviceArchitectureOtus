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

push:
	docker push $(DOCKER_USER)/auth-service:$(TAG)
	docker push $(DOCKER_USER)/profile-service:$(TAG)

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

test:
	newman run postman/collection.json --env-var baseUrl=http://arch.homework --reporters cli
