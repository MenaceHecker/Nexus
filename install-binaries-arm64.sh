
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}📦 Downloading ARM64 binaries for Apple Silicon...${NC}"

mkdir -p bin
cd bin

# Prometheus
if [ ! -f "prometheus" ]; then
    echo "Downloading Prometheus (ARM64)..."
    curl -sL "https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.darwin-arm64.tar.gz" | tar xz --strip-components=1 prometheus-2.45.0.darwin-arm64/prometheus
fi

# Grafana
if [ ! -f "grafana-server" ]; then
    echo "Downloading Grafana (ARM64)..."
    curl -sL "https://dl.grafana.com/oss/release/grafana-10.2.0.darwin-arm64.tar.gz" | tar xz
    mv grafana-v10.2.0/bin/grafana-server .
    rm -rf grafana-v10.2.0
fi

# AlertManager
if [ ! -f "alertmanager" ]; then
    echo "Downloading AlertManager (ARM64)..."
    curl -sL "https://github.com/prometheus/alertmanager/releases/download/v0.26.0/alertmanager-0.26.0.darwin-arm64.tar.gz" | tar xz --strip-components=1 alertmanager-0.26.0.darwin-arm64/alertmanager
fi

cd ..

echo -e "${GREEN}✅ ARM64 binaries installed!${NC}"
echo ""
echo "Testing..."
./bin/prometheus --version
./bin/grafana-server --version
./bin/alertmanager --version
EOF