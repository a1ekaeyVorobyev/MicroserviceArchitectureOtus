SERVICES=user billing order notification
DOCKER_USER=a1ekseyramblerru
tag=v3

.PHONY: compose-up compose-down docker-build docker-push minikube-start \
	 helm-install helm-delete helm-clean test-quick test-full clean-docker help

compose-up:
	 docker compose up -d

compose-down:
	 docker compose down

docker-build:
	 @echo "🔨 Сборка Docker образов..."
	 @for s in $(SERVICES); do \
	  echo "📦 Сборка $$s-service"; \
	  docker build -t $(DOCKER_USER)/$$s-service:$(tag) ./cmd/$$s; \
	 done
	 @echo "✅ Все образы собраны"

docker-push:
	 @echo "📤 Отправка образов в Docker Hub..."
	 @for s in $(SERVICES); do \
	  echo "🚀 Отправка $$s-service"; \
	  docker push $(DOCKER_USER)/$$s-service:$(tag); \
	 done
	 @echo "✅ Все образы отправлены"

docker-clean:
	 @echo "🧹 Очистка локальных Docker образов..."
	 @for s in $(SERVICES); do \
	  echo "Удаление $$s-service"; \
	  docker rmi $(DOCKER_USER)/$$s-service:latest 2>/dev/null || true; \
	 done
	 @echo "✅ Локальные образы удалены"

minikube-start:
	 @echo "🚀 Запуск Minikube..."
	 minikube start
	 minikube addons enable ingress
	 @echo "✅ Minikube готов. IP: $$(minikube ip)"

minikube-stop:
	 minikube stop

minikube-delete:
	 minikube delete

helm-install:
	 @echo "📦 Установка Helm чарта..."
	 helm upgrade --install arch ./helm/arch \
	  --namespace arch-homework \
	  --create-namespace \
	  --wait \
	  --timeout 5m
	 @echo "✅ Helm чарт установлен"

helm-delete:
	 @echo "🗑️ Удаление Helm релиза..."
	 -helm uninstall arch --namespace arch-homework 2>/dev/null
	 -kubectl delete namespace arch-homework --wait=true 2>/dev/null
	 @echo "✅ Helm релиз и namespace удалены"

helm-clean: helm-delete
	 @echo "✅ Полная очистка выполнена"

helm-status:
	 @echo "📊 Статус Helm релиза:"
	 helm list -n arch-homework
	 @echo "\n📊 Статус подов:"
	 kubectl get pods -n arch-homework
	 @echo "\n📊 Статус сервисов:"
	 kubectl get svc -n arch-homework
	 @echo "\n📊 Статус Ingress:"
	 kubectl get ingress -n arch-homework

test-quick:
	 @echo "⚡ Быстрый запуск тестов..."
	 bash ./scripts/quick-test.sh

test-full:
	 @echo "🔬 Полный запуск тестов с установкой..."
	 bash ./scripts/run-tests.sh

test-clean:
	 @echo "🧹 Очистка результатов тестов..."
	 rm -f test-results*.json
	 @echo "✅ Готово"

# Тестирование базы данных
test-db:
	    @echo "🧪 Запуск тестов базы данных..."
	    @./scripts/test-db.sh

port-forward:
	 @echo "🔌 Запуск port-forward для всех сервисов..."
	 @./scripts/start-port-forward.sh
port-forward-stop:
	 @echo "🔌 Остановка port-forward..."
	 @./scripts/stop-port-forward.sh
help:
	 @echo "📋 Доступные команды:"
	 @echo ""
	 @echo "  🏗️  Сборка:"
	 @echo "    make docker-build     - Собрать все Docker образы"
	 @echo "    make docker-push      - Отправить образы в Docker Hub"
	 @echo "    make docker-clean     - Удалить локальные образы"
	 @echo ""
	 @echo "  🚀 Minikube:"
	 @echo "    make minikube-start   - Запустить Minikube с ingress"
	 @echo "    make minikube-stop    - Остановить Minikube"
	 @echo "    make minikube-delete  - Удалить Minikube"
	 @echo ""
	 @echo "  📦 Helm:"
	 @echo "    make helm-install     - Установить Helm чарт"
	 @echo "    make helm-delete      - Удалить Helm релиз"
	 @echo "    make helm-clean       - Полная очистка"
	 @echo "    make helm-status      - Статус Helm и подов"
	 @echo ""
	 @echo "  🔌 Port-forward:"
	 @echo "    make port-forward     - Запустить port-forward"
	 @echo "    make port-forward-stop - Остановить port-forward"
	 @echo ""
	 @echo "  🧪 Тестирование:"
	 @echo "    make test-quick       - Быстрый запуск тестов"
	 @echo "    make test-full        - Полный запуск тестов"
	 @echo "    make test-clean       - Очистить результаты тестов"
	 @echo ""
	 @echo "  ❓ Другое:"
	 @echo "    make help             - Показать эту справку"