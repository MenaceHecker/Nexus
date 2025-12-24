#!/bin/bash

echo "Starting Monitoring Stack..."

# Check if core binaries exist
if [ ! -f "bin/prometheus" ]; then
    echo "⚠️  Core binaries not found. Running install..."
    ./install-binaries.sh
fi

# Check ELK binaries
if [ ! -d "bin/elasticsearch" ] || [ ! -d "bin/kibana" ] || [ ! -d "bin/filebeat" ]; then
    echo "⚠️  Elasticsearch/Kibana/Filebeat not found in ./bin."
    echo "    Make sure you installed them into ./bin before running start.sh"
    echo "    (Elasticsearch + Kibana arm64, Filebeat amd64 via Rosetta)"
    exit 1
fi

mkdir -p logs data/prometheus data/grafana data/alertmanager data/elasticsearch

# --- Elasticsearch ---
echo "Starting Elasticsearch..."
export ES_JAVA_HOME=$(/usr/libexec/java_home -v 11)
export ES_PATH_CONF="$(pwd)/config/elasticsearch"

nohup ./bin/elasticsearch/bin/elasticsearch \
    > logs/elasticsearch.log 2>&1 &
echo $! > logs/elasticsearch.pid

# --- Kibana ---
echo "Starting Kibana..."
nohup ./bin/kibana/bin/kibana \
    --config "$(pwd)/config/kibana/kibana.yml" \
    > logs/kibana.log 2>&1 &
echo $! > logs/kibana.pid

# --- Prometheus ---
echo "Starting Prometheus..."
nohup ./bin/prometheus \
    --config.file=config/prometheus/prometheus.yml \
    --storage.tsdb.path=data/prometheus \
    --web.listen-address=:9090 \
    > logs/prometheus.log 2>&1 &
echo $! > logs/prometheus.pid

# --- Grafana ---
echo "Starting Grafana..."
nohup ./bin/grafana-server \
    --config=config/grafana/grafana.ini \
    > logs/grafana.log 2>&1 &
echo $! > logs/grafana.pid

# --- AlertManager ---
echo "Starting AlertManager..."
nohup ./bin/alertmanager \
    --config.file=config/alertmanager/alertmanager.yml \
    --storage.path=data/alertmanager \
    > logs/alertmanager.log 2>&1 &
echo $! > logs/alertmanager.pid

# --- User Service ---
echo "Starting User Service..."
cd services/user-service
source venv/bin/activate
nohup python app.py > ../../logs/user-service.log 2>&1 &
echo $! > ../../logs/user-service.pid
deactivate
cd ../..

# --- Filebeat (amd64, requires Rosetta on Apple Silicon) ---
echo "Starting Filebeat..."
nohup arch -x86_64 ./bin/filebeat/filebeat \
    -c "$(pwd)/config/filebeat/filebeat.yml" \
    -e \
    > logs/filebeat.log 2>&1 &
echo $! > logs/filebeat.pid

sleep 3
echo ""
echo "✅ Services started!"
echo ""
echo "🌐 Access:"
echo "  • Prometheus:   http://localhost:9090"
echo "  • Grafana:      http://localhost:3000 (admin/admin)"
echo "  • AlertManager: http://localhost:9093"
echo "  • User Service: http://localhost:8081"
echo "  • Elasticsearch: http://localhost:9200"
echo "  • Kibana:       http://localhost:5601"
echo ""
echo "📊 Check: ./status.sh"
echo "🛑 Stop:  ./stop.sh"
