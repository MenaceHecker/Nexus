#!/bin/bash

echo "📊 Service Status:"
echo ""

check() {
    if curl -s "$1" > /dev/null 2>&1; then
        echo "✅ $2"
    else
        echo "❌ $2"
    fi
}

check "http://localhost:9090/-/healthy" "Prometheus (port 9090)"
check "http://localhost:3000/api/health" "Grafana (port 3000)"
check "http://localhost:9093/-/healthy" "AlertManager (port 9093)"
check "http://localhost:8081/health" "User Service (port 8081)"
check "http://127.0.0.1:9200" "Elasticsearch (port 9200)"
check "http://localhost:5601" "Kibana (port 5601)"
