#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}📦 Downloading monitoring binaries...${NC}"

OS=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="darwin-amd64"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux-amd64"
fi

mkdir -p bin

# Prometheus
if [ ! -f "bin/prometheus" ]; then
    echo "Downloading Prometheus..."
    curl -sL "https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.${OS}.tar.gz" \
        | tar xz -C bin --strip-components=1 prometheus-2.45.0.${OS}/prometheus
fi

# Grafana
if [ ! -f "bin/grafana-server" ]; then
    echo "Downloading Grafana..."
    curl -sL "https://dl.grafana.com/oss/release/grafana-10.2.0.${OS}.tar.gz" \
        | tar xz -C bin --strip-components=2 grafana-10.2.0/bin/grafana-server
fi

# AlertManager
if [ ! -f "bin/alertmanager" ]; then
    echo "Downloading AlertManager..."
    curl -sL "https://github.com/prometheus/alertmanager/releases/download/v0.26.0/alertmanager-0.26.0.${OS}.tar.gz" \
        | tar xz -C bin --strip-components=1 alertmanager-0.26.0.${OS}/alertmanager
fi

echo -e "${GREEN}✅ Binaries installed to bin/${NC}"
