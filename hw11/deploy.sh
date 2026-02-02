#!/bin/bash
set -e

# -----------------------
# Настройки
# -----------------------
NAMESPACE=m
DOCKER_USER=a1ekseyramblerru
IMAGE_NAME=health-service
IMAGE_TAG=latest
STUDENT_NAME=vorobyev

# -----------------------
# 1️⃣ Проверка Helm
# -----------------------
if ! command -v helm &> /dev/null; then
    echo "Helm не найден. Устанавливаем..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "Helm version:"
helm version

# -----------------------
# 2️⃣ Minikube IP и /etc/hosts
# -----------------------
MINIKUBE_IP=$(minikube ip)
echo "Minikube IP: $MINIKUBE_IP"

if ! grep -q "arch.homework" /etc/hosts; then
    echo "Добавляем arch.homework в /etc/hosts"
    echo "$MINIKUBE_IP arch.homework" | sudo tee -a /etc/hosts
fi

# -----------------------
# 3️⃣ Namespace
# -----------------------
kubectl create ns $NAMESPACE 2>/dev/null || true

# -----------------------
# 4️⃣ Установка nginx ingress через Helm
# -----------------------
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx/ 2>/dev/null || true
helm repo update

# Удаляем старый релиз, если есть
if helm status nginx -n $NAMESPACE &> /dev/null; then
    echo "Удаляем старый релиз nginx..."
    helm uninstall nginx -n $NAMESPACE
    sleep 10
fi

echo "Устанавливаем ingress-nginx..."
if [[ -f "nginx-ingress.yaml" ]]; then
    helm install nginx ingress-nginx/ingress-nginx -n $NAMESPACE -f nginx-ingress.yaml
else
    helm install nginx ingress-nginx/ingress-nginx -n $NAMESPACE \
      --set controller.ingressClassResource.name=nginx-m \
      --set controller.ingressClass=nginx-m \
      --set controller.service.type=NodePort \
      --set controller.service.nodePorts.http=30080 \
      --set controller.service.nodePorts.https=30443
fi

# -----------------------
# 5️⃣ Ждём готовность контроллера
# -----------------------
echo "Ждём готовность ingress-nginx controller..."
for i in {1..30}; do
    if kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=ingress-nginx 2>/dev/null | grep -q "1/1.*Running"; then
        echo "✓ Ingress controller готов"
        break
    fi
    [[ $i -eq 30 ]] && echo "⚠ Таймаут ожидания ingress controller" && exit 1
    echo "Ожидание ingress controller ($i/30)..."
    sleep 2
done

echo "Проверяем NodePort сервис:"
kubectl get svc nginx-ingress-nginx-controller -n $NAMESPACE

# -----------------------
# 6️⃣ Применяем Deployment/Service/Ingress
# -----------------------
echo "Применяем манифесты..."
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

echo "Удаляем старый ingress если есть..."
kubectl delete ingress health-ingress -n $NAMESPACE 2>/dev/null || true
sleep 2

echo "Применяем ingress..."
kubectl apply -f k8s/ingress.yaml

# -----------------------
# 7️⃣ Ждём готовность подов сервиса
# -----------------------
echo "Ждём готовность подов сервиса..."
for i in {1..30}; do
    READY=$(kubectl get deployment health-service -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED=$(kubectl get deployment health-service -n $NAMESPACE -o jsonpath='{.status.replicas}' 2>/dev/null || echo "0")
    
    if [[ "$READY" == "$DESIRED" ]] && [[ "$DESIRED" -gt 0 ]]; then
        echo "✓ Поды сервиса готовы ($READY/$DESIRED)"
        break
    fi
    [[ $i -eq 30 ]] && echo "⚠ Таймаут ожидания подов сервиса" && exit 1
    echo "Ожидание подов сервиса ($i/30)..."
    sleep 2
done

echo "Статус всех подов:"
kubectl get pods -n $NAMESPACE

# -----------------------
# 8️⃣ Проверяем сервисы и endpoints
# -----------------------
echo "Проверяем сервисы и endpoints:"
kubectl get svc,ep -n $NAMESPACE

# -----------------------
# 9️⃣ Тестируем напрямую (минуя ingress)
# -----------------------
echo -e "\n=== Тестируем напрямую (минуя ingress) ==="
kubectl port-forward -n $NAMESPACE svc/health-service 8081:80 >/dev/null 2>&1 &
PF_SERVICE_PID=$!
sleep 5

echo "1. Прямой доступ /health:"
if curl -s --max-time 5 http://localhost:8081/health 2>/dev/null | grep -q "status"; then
    curl -s http://localhost:8081/health | jq -c '.'
    echo "✓ Прямой доступ работает"
else
    echo "✗ Прямой доступ не работает"
fi

echo -e "\n2. Прямой доступ /otusapp/$STUDENT_NAME/health (ожидаем 404):"
if curl -s --max-time 5 http://localhost:8081/otusapp/$STUDENT_NAME/health 2>/dev/null | grep -q "404"; then
    echo "✓ 404 как и ожидалось (приложение не имеет этого пути)"
else
    echo "⚠ Неожиданный ответ"
fi

kill $PF_SERVICE_PID 2>/dev/null || true

# -----------------------
# 🔟 Тестируем через ingress (надежный способ через minikube ssh)
# -----------------------
echo -e "\n=== Тестируем через ingress (изнутри minikube) ==="

# Функция для тестирования через minikube ssh
test_via_minikube() {
    local path=$1
    local description=$2
    
    echo -e "\n$description:"
    local output
    output=$(minikube ssh -- "curl -s --max-time 5 -H 'Host: arch.homework' http://localhost:30080$path 2>/dev/null" 2>/dev/null)
    
    if echo "$output" | grep -q "status"; then
        echo "$output" | jq -c '.'
        echo "✓ Работает"
        return 0
    elif echo "$output" | grep -q "404"; then
        echo "✗ 404 Not Found"
        return 1
    elif [[ -z "$output" ]]; then
        echo "⚠ Нет ответа (таймаут)"
        return 1
    else
        echo "⚠ Неожиданный ответ: $output"
        return 1
    fi
}

# Тестируем основные пути
test_via_minikube "/health" "1. /health"
test_via_minikube "/otusapp/$STUDENT_NAME/health" "2. /otusapp/$STUDENT_NAME/health"
test_via_minikube "/otusapp/aeugene/health" "3. /otusapp/aeugene/health"
test_via_minikube "/otusapp/teststudent/health" "4. /otusapp/teststudent/health"

# -----------------------
# 🔟1️⃣ Альтернативный тест через port-forward к ingress
# -----------------------
echo -e "\n=== Альтернативный тест через port-forward к ingress ==="
kubectl port-forward -n $NAMESPACE svc/nginx-ingress-nginx-controller 8888:80 >/dev/null 2>&1 &
PF_INGRESS_PID=$!
sleep 5

echo "Тестируем через port-forward 8888:"
echo "1. /health:"
if curl -s --max-time 5 -H "Host: arch.homework" http://localhost:8888/health 2>/dev/null | grep -q "status"; then
    curl -s -H "Host: arch.homework" http://localhost:8888/health | jq -c '.'
    echo "✓ Работает через port-forward"
else
    echo "✗ Не работает через port-forward"
fi

echo -e "\n2. /otusapp/$STUDENT_NAME/health:"
if curl -s --max-time 5 -H "Host: arch.homework" http://localhost:8888/otusapp/$STUDENT_NAME/health 2>/dev/null | grep -q "status"; then
    curl -s -H "Host: arch.homework" http://localhost:8888/otusapp/$STUDENT_NAME/health | jq -c '.'
    echo "✓ Работает через port-forward"
else
    echo "✗ Не работает через port-forward"
fi

kill $PF_INGRESS_PID 2>/dev/null || true

# -----------------------
# 🔟2️⃣ Финальная проверка конфигурации
# -----------------------
echo -e "\n=== Финальная проверка конфигурации ==="
echo "1. Ingress:"
kubectl get ingress -n $NAMESPACE

echo -e "\n2. Ingress правила:"
kubectl describe ingress health-ingress -n $NAMESPACE | grep -A10 "Rules:"

echo -e "\n3. Проверка rewrite аннотации:"
kubectl get ingress health-ingress -n $NAMESPACE -o jsonpath='{.metadata.annotations}' | jq -r '."nginx.ingress.kubernetes.io/rewrite-target"'

echo -e "\n4. Проверка ingress class:"
kubectl get ingressclass nginx-m 2>/dev/null && echo "✓ Ingress class nginx-m существует"

# -----------------------
# 🔟3️⃣ Сводка
# -----------------------
echo -e "\n=== Сводка ==="
echo "✅ Развертывание завершено"
echo "📡 Доступные endpoint'ы:"
echo "   - http://arch.homework/health"
echo "   - http://arch.homework/otusapp/{student_name}/health"
echo ""
echo "🔧 Для тестирования используйте:"
echo "   Изнутри minikube: curl -H 'Host: arch.homework' http://localhost:30080/health"
echo "   Через port-forward: kubectl port-forward -n m svc/nginx-ingress-nginx-controller 8080:80"
echo "   Затем: curl -H 'Host: arch.homework' http://localhost:8080/otusapp/vorobyev/health"
echo ""
echo "📝 Ingress настроен с rewrite-target: /otusapp/{student_name}/health → /health"