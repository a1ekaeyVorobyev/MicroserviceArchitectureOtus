NAMESPACE=monitoring
APP_RELEASE=monitoring-app
STACK_RELEASE=kube-prometheus-stack
CHART_PATH=./helm/monitoring-app

install-stack:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
	helm repo update
	helm upgrade --install $(STACK_RELEASE) prometheus-community/kube-prometheus-stack -n $(NAMESPACE) --create-namespace

install-app:
	helm upgrade --install $(APP_RELEASE) $(CHART_PATH) -n $(NAMESPACE)

install: install-stack install-app

k8s-test:
	helm upgrade --install $(APP_RELEASE) $(CHART_PATH) -n $(NAMESPACE)
	kubectl wait --for=condition=complete job/$(APP_RELEASE)-e2e -n $(NAMESPACE) --timeout=300s
	kubectl logs job/$(APP_RELEASE)-e2e -n $(NAMESPACE)

helm-test:
	helm test $(APP_RELEASE) -n $(NAMESPACE)

helm-upgrade:
	kubectl delete job monitoring-app-e2e -n monitoring --ignore-not-found
	helm upgrade --install monitoring-app ./helm/monitoring-app -n monitoring

forfard-grafana
    kubectl port-forward svc/kube-prom-grafana -n monitoring 3000:80

uninstall:
	helm uninstall $(APP_RELEASE) -n $(NAMESPACE) || true
	helm uninstall $(STACK_RELEASE) -n $(NAMESPACE) || true
	kubectl delete namespace $(NAMESPACE) --ignore-not-found
