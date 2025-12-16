#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Monitoring Stack Auto Setup Script          ║${NC}"
echo -e "${BLUE}║   Prometheus + Elasticsearch + Kibana          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker is running${NC}"
echo ""

# Create directory structure
echo -e "${YELLOW}📁 Creating directory structure...${NC}"
mkdir -p prometheus
mkdir -p alertmanager
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards
mkdir -p filebeat
mkdir -p postgres
mkdir -p services/user-service

echo -e "${GREEN}✅ Directories created${NC}"
echo ""