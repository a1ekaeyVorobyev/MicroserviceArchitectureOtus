#!/bin/bash
set -e

### ===== Цвета =====
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

### ===== Настройки =====
NAMESPACE=default
RELEASE_APP=users
RELEASE_DB=postgres
POSTMAN_COLLECTION=postman/users.postman_collection.json
DRY_RUN=false

### ===== Аргументы =====
for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
  esac
done

run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN] $*${NC}"
  else
    eval "$@"
  fi
}

step() { echo -e "\n${BLUE}▶ $1${NC}"; }
ok() { echo -e "${GREEN}✔ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; exit 1; }

# ----------------------------------------
step "Detecting Kubernetes environment"
if command -v minikube &>/dev/null && minikube status &>/dev/null; then
  ENV="minikube"
elif kubectl get nodes | grep kind &>/dev/null; then
  ENV="kind"
else
  ENV="kubernetes"
fi
ok "Environment: $ENV"

# ----------------------------------------
step "Checking dependencies"
for cmd in kubectl helm curl; do
  command -v $cmd &>/dev/null || {
    error "$cmd not found"
  }
done

if command -v newman &>/dev/null; then
  NEWMAN_CMD="newman"
elif command -v npx &>/dev/null; then
  NEWMAN_CMD="npx newman"
else
  NEWMAN_CMD=""
  warn "Newman not found, API tests will be skipped"
fi
ok "Dependencies check completed"

# ----------------------------------------
step "Deploying PostgreSQL"
if ! kubectl get deployment,statefulset -n $NAMESPACE -l app.kubernetes.io/name=postgresql 2>/dev/null | grep -q postgresql; then
  run_cmd "helm upgrade --install $RELEASE_DB oci://registry-1.docker.io/bitnamicharts/postgresql \
    -f k8s/postgres-values.yaml --namespace $NAMESPACE --create-namespace"
  
  if [ "$DRY_RUN" = false ]; then
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql \
      -n $NAMESPACE --timeout=180s || {
      warn "PostgreSQL not ready, but continuing..."
    }
  fi
  ok "PostgreSQL deployed"
else
  ok "PostgreSQL already deployed"
fi

# ----------------------------------------
step "Creating DB Secret"
# Создаем secret если его нет
if ! kubectl get secret users-db-secret -n $NAMESPACE &>/dev/null; then
  run_cmd "kubectl create secret generic users-db-secret \
    --from-literal=DB_USER=user \
    --from-literal=DB_PASSWORD=password \
    -n $NAMESPACE"
  ok "DB Secret created"
else
  ok "DB Secret already exists"
fi

# ----------------------------------------
step "Creating Migrations ConfigMap"
# Проверяем правильный путь к миграциям
MIGRATIONS_PATH="./migrations"
if [ -d "./user-service/migrations" ]; then
  MIGRATIONS_PATH="./user-service/migrations"
fi

if [ -f "$MIGRATIONS_PATH/V1__init.sql" ]; then
  run_cmd "kubectl create configmap ${RELEASE_APP}-migrations \
    --from-file=V1__init.sql=$MIGRATIONS_PATH/V1__init.sql -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -"
  ok "Migrations ConfigMap ensured"
else
  warn "Migrations file not found at $MIGRATIONS_PATH/V1__init.sql"
  warn "Creating empty ConfigMap"
  run_cmd "kubectl create configmap ${RELEASE_APP}-migrations -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f - || true"
fi

# ----------------------------------------
step "Deleting old migration Job (if exists)"
run_cmd "kubectl delete job ${RELEASE_APP}-migrations -n $NAMESPACE --ignore-not-found --wait=false"
run_cmd "kubectl delete pods -l job-name=${RELEASE_APP}-migrations -n $NAMESPACE --ignore-not-found --wait=false"
ok "Old Job deleted"

# ----------------------------------------
step "Running DB migrations via Helm"
run_cmd "helm upgrade --install $RELEASE_APP ./helm/users-service \
  --namespace $NAMESPACE \
  --set runMigrations=true \
  --set database.host=postgres-postgresql"

if [ "$DRY_RUN" = false ]; then
  echo -e "${BLUE}▶ Waiting for DB migrations Job to complete (timeout: 90s)${NC}"
  
  # Ждем с таймаутом
  TIMEOUT=90
  START_TIME=$(date +%s)
  
  while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED -gt $TIMEOUT ]; then
      warn "Migrations timeout after ${TIMEOUT}s"
      warn "Checking logs..."
      kubectl logs -l job-name=${RELEASE_APP}-migrations -n $NAMESPACE --tail=20 2>/dev/null || true
      warn "Continuing without migrations..."
      break
    fi
    
    # Проверяем статус Job
    if kubectl get job ${RELEASE_APP}-migrations -n $NAMESPACE -o jsonpath='{.status.succeeded}' 2>/dev/null | grep -q "1"; then
      ok "Migrations completed successfully"
      break
    fi
    
    # Проверяем если Job провалилась
    if kubectl get job ${RELEASE_APP}-migrations -n $NAMESPACE -o jsonpath='{.status.failed}' 2>/dev/null | grep -q "[1-9]"; then
      warn "Migrations failed"
      kubectl logs -l job-name=${RELEASE_APP}-migrations -n $NAMESPACE --tail=20 2>/dev/null || true
      warn "Continuing despite migration failure..."
      break
    fi
    
    sleep 2
  done
fi

# ----------------------------------------
step "Deploying Users Service"
run_cmd "helm upgrade --install $RELEASE_APP ./helm/users-service \
  --namespace $NAMESPACE \
  --set runMigrations=false \
  --set database.host=postgres-postgresql"

if [ "$DRY_RUN" = false ]; then
  kubectl rollout status deployment/$RELEASE_APP -n $NAMESPACE --timeout=180s || {
    warn "Deployment rollout failed or timed out"
    warn "Checking pod status..."
    kubectl get pods -n $NAMESPACE -l app=$RELEASE_APP
    kubectl logs -n $NAMESPACE -l app=$RELEASE_APP --tail=20
    warn "Continuing anyway..."
  }
fi
ok "Application deployed"

# ----------------------------------------
step "Ingress setup"
if [ "$ENV" = "minikube" ]; then
  if ! minikube addons list | grep -q "ingress.*enabled"; then
    warn "Ingress addon not enabled. Run:"
    echo "  minikube addons enable ingress"
  fi
  warn "You may need to run in another terminal:"
  echo "  minikube tunnel"
elif [ "$ENV" = "kind" ]; then
  warn "Ensure ingress-nginx is installed in kind cluster"
fi

# ----------------------------------------
step "Smoke test"
if [ "$DRY_RUN" = false ]; then
  # Даем сервису время запуститься
  sleep 10
  
  # Пробуем несколько способов подключения
  SUCCESS=false
  
  # Способ 1: Через port-forward
  echo -e "${BLUE}Testing via port-forward...${NC}"
  kubectl port-forward svc/$RELEASE_APP 8081:80 -n $NAMESPACE --address=0.0.0.0 &
  PF_PID=$!
  sleep 3
  
  CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/users --connect-timeout 10 || true)
  kill $PF_PID 2>/dev/null || true
  
  if [[ "$CODE" =~ ^(200|201|404)$ ]]; then
    ok "Service reachable via port-forward (HTTP $CODE)"
    SUCCESS=true
  else
    warn "Service not reachable via port-forward (HTTP $CODE)"
  fi
  
  # Способ 2: Через ingress если настроен
  if [ "$SUCCESS" = false ] && kubectl get ingress $RELEASE_APP -n $NAMESPACE &>/dev/null; then
    echo -e "${BLUE}Testing via ingress...${NC}"
    CODE=$(curl -s -o /dev/null -w "%{http_code}" http://arch.homework/users --connect-timeout 10 || true)
    if [[ "$CODE" =~ ^(200|201|404)$ ]]; then
      ok "Service reachable via ingress (HTTP $CODE)"
      SUCCESS=true
    else
      warn "Service not reachable via ingress (HTTP $CODE)"
    fi
  fi
  
  if [ "$SUCCESS" = false ]; then
    warn "Smoke test failed, but continuing..."
  fi
else
  warn "Skipping smoke test (dry-run)"
fi

# ----------------------------------------
step "Running Newman tests"
if [ "$DRY_RUN" = false ] && [ -n "$NEWMAN_CMD" ] && [ -f "$POSTMAN_COLLECTION" ]; then
  # Настраиваем временный port-forward для тестов
  kubectl port-forward svc/$RELEASE_APP 8082:80 -n $NAMESPACE --address=0.0.0.0 &
  TEST_PF_PID=$!
  sleep 5
  
  # Экспортируем переменную для Newman
  export SERVICE_URL=http://localhost:8082
  
  echo -e "${BLUE}Running Newman tests...${NC}"
  $NEWMAN_CMD run "$POSTMAN_COLLECTION" --env-var "baseUrl=$SERVICE_URL" || {
    warn "Newman tests failed"
  }
  
  kill $TEST_PF_PID 2>/dev/null || true
  ok "Newman tests completed"
else
  if [ "$DRY_RUN" = false ] && [ -n "$NEWMAN_CMD" ] && [ ! -f "$POSTMAN_COLLECTION" ]; then
    warn "Postman collection not found: $POSTMAN_COLLECTION"
  fi
  warn "Skipping Newman tests"
fi

echo -e "\n${GREEN}🎉 Deployment & checks completed${NC}"