#!/bin/bash
set +e

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

step() {
  echo -e "\n${BLUE}▶ $1${NC}"
}

ok() {
  echo -e "${GREEN}✔ $1${NC}"
}

---

step "Removing Users Service"

run_cmd "helm uninstall $RELEASE_APP --namespace $NAMESPACE"
ok "Users Service removed"

---

step "Removing PostgreSQL"

run_cmd "helm uninstall $RELEASE_DB --namespace $NAMESPACE"
ok "PostgreSQL removed"

---

step "Removing migration Job"

run_cmd "kubectl delete job users-db-migrations --ignore-not-found"
ok "Migration job removed"

---

step "Cleanup completed"
echo -e "${GREEN}🧹 Environment cleaned${NC}"
