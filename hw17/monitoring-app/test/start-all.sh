#!/bin/bash
echo "🚀 Starting Monitoring Stack..."

# 1. Build app
echo "1. Building Go application..."
docker-compose build app

# 2. Start services
echo "2. Starting all services..."
docker-compose up -d

# 3. Wait and check
echo "3. Waiting for services to start..."
sleep 30

# 4. Check status
echo "4. Checking service status..."
echo "================================"

check_service() {
    local name=$1
    local url=$2
    echo -n "$name: "
    if curl -s -f "$url" > /dev/null 2>&1; then
        echo "✅ RUNNING"
        echo "   URL: $url"
    else
        echo "❌ NOT RESPONDING"
    fi
}

check_service "Go App" "http://localhost:8080/health"
check_service "Prometheus" "http://localhost:9090/-/healthy"
check_service "Grafana" "http://localhost:3000/api/health"

echo -e "\n5. All services should be running:"
docker-compose ps

echo -e "\n6. URLs:"
echo "   - App:        http://localhost:8080"
echo "   - Metrics:    http://localhost:8080/metrics"
echo "   - Prometheus: http://localhost:9090"
echo "   - Grafana:    http://localhost:3000 (admin/admin)"

echo -e "\n7. Next steps:"
echo "   - Open Grafana: http://localhost:3000"
echo "   - Login: admin/admin"
echo "   - Create alerts manually (see CREATE_ALERTS.md)"
