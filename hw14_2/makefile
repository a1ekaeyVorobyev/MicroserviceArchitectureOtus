# ======================
# Users Service Makefile
# ======================

NAMESPACE ?= default
APP_RELEASE ?= users
DB_RELEASE ?= postgres
POSTMAN_COLLECTION ?= postman/users.postman_collection.json
DRY ?= false

GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
RED=\033[0;31m
NC=\033[0m

.PHONY: help
help:
	@echo -e "$(BLUE)Usage:$(NC)"
	@echo "  make run            - deploy app + DB + run migrations + test API"
	@echo "  make run DRY=true   - same as run, but dry-run"
	@echo "  make clean          - delete all resources"
	@echo "  make test           - run Newman tests only"
	@echo "  make db             - deploy DB only"

.PHONY: run
run:
	@echo -e "$(BLUE)▶ Running full deployment$(NC)"
	@./run_and_check.sh $(if $(filter true,$(DRY)),--dry-run,)

.PHONY: clean
clean:
	@echo -e "$(BLUE)▶ Cleaning up environment$(NC)"
	@./cleanup.sh $(if $(filter true,$(DRY)),--dry-run,)

.PHONY: test
test:
	@echo -e "$(BLUE)▶ Running Newman tests$(NC)"
	@if [ "$(DRY)" = "true" ]; then \
	echo -e "$(YELLOW)[DRY-RUN] newman run $(POSTMAN_COLLECTION)$(NC)"; \
	else \
	newman run $(POSTMAN_COLLECTION); \
	fi

.PHONY: db
db:
	@echo -e "$(BLUE)▶ Deploying PostgreSQL DB$(NC)"
	@if [ "$(DRY)" = "true" ]; then \
	echo -e "$(YELLOW)[DRY-RUN] helm upgrade --install $(DB_RELEASE) oci://registry-1.docker.io/bitnamicharts/postgresql -f k8s/postgres-values.yaml --namespace $(NAMESPACE)$(NC)"; \
	else \
	helm upgrade --install $(DB_RELEASE) oci://registry-1.docker.io/bitnamicharts/postgresql -f k8s/postgres-values.yaml --namespace $(NAMESPACE) --create-namespace; \
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql --timeout=180s; \
	fi
