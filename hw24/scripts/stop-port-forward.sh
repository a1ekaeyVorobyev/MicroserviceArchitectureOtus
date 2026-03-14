#!/bin/bash

echo "🔌 Остановка port-forward процессов..."
pkill -f "kubectl port-forward"
rm -f /tmp/pf-*.log /tmp/pf-pids.tmp 2>/dev/null
echo "✅ Port-forward остановлен"
