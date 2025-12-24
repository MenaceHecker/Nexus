#!/bin/bash

echo "🚀 Starting Monitoring Stack..."

# Check if binaries exist
if [ ! -f "bin/prometheus" ]; then
    echo "⚠️  Binaries not found. Running install..."
    ./install-binaries.sh
fi

mkdir -p logs data/prometheus data/grafana

# Start Prometheus
echo "Starting Prometheus..."
nohup ./bin/prometheus \
    --config.file=config/prometheus/prometheus.yml \
    --storage.tsdb.path=data/prometheus \
    --web.listen-address=:9090 \
    > logs/prometheus.log 2>&1 &
echo $! > logs/prometheus.pid

# Start Grafana
echo "Starting Grafana..."
nohup ./bin/grafana-server \
    --homepath=. \
    --config=config/grafana/provisioning/datasources/datasources.yml \
    > logs/grafana.log 2>&1 &
echo $! > logs/grafana.pid

# Start AlertManager
echo "Starting AlertManager..."
nohup ./bin/alertmanager \
    --config.file=config/alertmanager/alertmanager.yml \
    --storage.path=data/alertmanager \
    > logs/alertmanager.log 2>&1 &
echo $! > logs/alertmanager.pid

# Start User Service
echo "Starting User Service..."
cd services/user-service
source venv/bin/activate
nohup python app.py > ../../logs/user-service.log 2>&1 &
echo $! > ../../logs/user-service.pid
deactivate
cd ../..

sleep 3
echo ""
echo "✅ Services started!"
echo ""
echo "🌐 Access:"
echo "  • Prometheus:  http://localhost:9090"
echo "  • Grafana:     http://localhost:3000 (admin/admin)"
echo "  • User Service: http://localhost:8081"
echo ""
echo "📊 Check: ./status.sh"
echo "🛑 Stop:  ./stop.sh"
