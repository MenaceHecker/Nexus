#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Lightweight Monitoring Stack Setup          ║${NC}"
echo -e "${BLUE}║   (GitHub-friendly - Downloads on first run)   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Detect OS
OS=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    ARCH="darwin-amd64"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    ARCH="linux-amd64"
else
    echo -e "${RED}❌ Unsupported OS${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Detected: $OS${NC}"
echo ""

# Create directory structure
echo -e "${YELLOW}📁 Creating directories...${NC}"
mkdir -p bin
mkdir -p config/{prometheus,grafana,alertmanager}
mkdir -p data/{prometheus,grafana}
mkdir -p logs
mkdir -p services/user-service

echo -e "${GREEN}✅ Directories created${NC}"
echo ""

# Create .gitignore
cat > .gitignore << 'EOF'
# Binaries (downloaded at runtime)
bin/

# Data directories
data/
logs/

# Python
services/*/venv/
*.pyc
__pycache__/

# OS files
.DS_Store
*.pid
EOF

echo -e "${GREEN}✅ .gitignore created${NC}"

# ==================== Config Files ====================
echo -e "${YELLOW}📝 Creating config files...${NC}"

# Prometheus config
cat > config/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

rule_files:
  - "alerts.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'user-service'
    static_configs:
      - targets: ['localhost:8081']
    metrics_path: '/metrics'
EOF

cat > config/prometheus/alerts.yml << 'EOF'
groups:
  - name: service_alerts
    interval: 30s
    rules:
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
EOF

# Grafana datasource
mkdir -p config/grafana/provisioning/datasources
cat > config/grafana/provisioning/datasources/datasources.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
EOF

# AlertManager config
cat > config/alertmanager/alertmanager.yml << 'EOF'
global:
  resolve_timeout: 5m

route:
  receiver: 'default'

receivers:
  - name: 'default'
EOF

echo -e "${GREEN}✅ Config files created${NC}"

# ==================== User Service ====================
echo -e "${YELLOW}📝 Creating User Service...${NC}"

cat > services/user-service/requirements.txt << 'EOF'
flask==3.0.0
prometheus-client==0.19.0
psycopg2-binary==2.9.9
EOF

cat > services/user-service/app.py << 'EOF'
from flask import Flask, request, jsonify
from prometheus_client import Counter, Histogram, Gauge, generate_latest, REGISTRY
import psycopg2
import time
import logging
import json
import os

# JSON logging
class JsonFormatter(logging.Formatter):
    def format(self, record):
        return json.dumps({
            'timestamp': self.formatTime(record),
            'level': record.levelname,
            'service': 'user-service',
            'message': record.getMessage()
        })

os.makedirs('../../logs', exist_ok=True)
handler = logging.FileHandler('../../logs/user-service.log')
handler.setFormatter(JsonFormatter())
console = logging.StreamHandler()
logging.basicConfig(level=logging.INFO, handlers=[handler, console])

app = Flask(__name__)
logger = logging.getLogger(__name__)

# Metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'Request duration', ['method', 'endpoint'])
USER_COUNT = Gauge('users_total', 'Total users')

def get_db():
    return psycopg2.connect(
        host='localhost',
        database='users_db',
        user='postgres',
        password='postgres'
    )

def init_db():
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(100) UNIQUE NOT NULL,
                email VARCHAR(100) UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        conn.commit()
        conn.close()
        logger.info("Database initialized")
    except Exception as e:
        logger.error(f"DB init failed: {str(e)}")

@app.before_request
def before():
    request.start_time = time.time()

@app.after_request
def after(response):
    duration = time.time() - request.start_time
    REQUEST_DURATION.labels(method=request.method, endpoint=request.path).observe(duration)
    REQUEST_COUNT.labels(method=request.method, endpoint=request.path, status=response.status_code).inc()
    logger.info(f"{request.method} {request.path} {response.status_code}")
    return response

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'user-service'}), 200

@app.route('/metrics')
def metrics():
    return generate_latest(REGISTRY)

@app.route('/users', methods=['GET'])
def get_users():
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute('SELECT id, username, email, created_at FROM users')
        users = [{'id': r[0], 'username': r[1], 'email': r[2], 'created_at': str(r[3])} for r in cur.fetchall()]
        conn.close()
        USER_COUNT.set(len(users))
        return jsonify({'users': users, 'count': len(users)}), 200
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/users', methods=['POST'])
def create_user():
    try:
        data = request.get_json()
        if not data or 'username' not in data or 'email' not in data:
            return jsonify({'error': 'Missing username or email'}), 400
        
        conn = get_db()
        cur = conn.cursor()
        cur.execute('INSERT INTO users (username, email) VALUES (%s, %s) RETURNING id',
                   (data['username'], data['email']))
        user_id = cur.fetchone()[0]
        conn.commit()
        conn.close()
        logger.info(f"Created user: {user_id}")
        return jsonify({'id': user_id, 'username': data['username'], 'email': data['email']}), 201
    except psycopg2.IntegrityError:
        return jsonify({'error': 'Username or email already exists'}), 409
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute('SELECT id, username, email, created_at FROM users WHERE id = %s', (user_id,))
        user = cur.fetchone()
        conn.close()
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        return jsonify({'id': user[0], 'username': user[1], 'email': user[2], 'created_at': str(user[3])}), 200
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=8081)
EOF

# Setup Python venv
echo -e "${YELLOW}Setting up Python environment...${NC}"
cd services/user-service
python3 -m venv venv
source venv/bin/activate
pip install --quiet -r requirements.txt
deactivate
cd ../..

echo -e "${GREEN}✅ User Service ready${NC}"

# ==================== Install Script ====================
echo -e "${YELLOW}📝 Creating install script...${NC}"

cat > install-binaries.sh << 'INSTALLEOF'
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
INSTALLEOF

chmod +x install-binaries.sh

# ==================== Control Scripts ====================

cat > start.sh << 'STARTEOF'
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
STARTEOF

cat > stop.sh << 'STOPEOF'
#!/bin/bash

echo "🛑 Stopping services..."

for pid_file in logs/*.pid; do
    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file")
        if ps -p $pid > /dev/null 2>&1; then
            kill $pid 2>/dev/null
            echo "Stopped $(basename $pid_file .pid)"
        fi
        rm "$pid_file"
    fi
done

echo "✅ All services stopped"
STOPEOF

cat > status.sh << 'STATUSEOF'
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
STATUSEOF

chmod +x start.sh stop.sh status.sh install-binaries.sh

# ==================== README ====================

cat > README.md << 'EOF'
# Monitoring Stack with Prometheus, Elasticsearch & Kibana

A lightweight, production-ready monitoring stack that's GitHub-friendly. Binaries are downloaded on first run, keeping the repo size small (~50KB).

## 📦 What's Included

- **Prometheus** - Metrics collection and alerting
- **Grafana** - Metrics visualization
- **AlertManager** - Alert routing
- **User Service** - Sample Python Flask microservice with metrics

## 🚀 Quick Start

### Prerequisites

Install PostgreSQL:

**macOS:**
```bash
brew install postgresql@15
brew services start postgresql@15
```

**Ubuntu/Debian:**
```bash
sudo apt-get install postgresql
sudo systemctl start postgresql
```

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd monitoring-stack

# Run setup (creates config, installs Python deps)
chmod +x setup.sh
./setup.sh
```

### 2. Initialize Database

```bash
# Create database
createdb users_db

# Set password (if needed)
psql -d postgres -c "ALTER USER postgres PASSWORD 'postgres';"
```

### 3. Start Everything

```bash
./start.sh
```

This will automatically download binaries on first run (~100MB total).

### 4. Verify

```bash
./status.sh
```

## 🌐 Access URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Prometheus | http://localhost:9090 | - |
| Grafana | http://localhost:3000 | admin/admin |
| AlertManager | http://localhost:9093 | - |
| User Service | http://localhost:8081 | - |

## 🧪 Test the User Service

```bash
# Create a user
curl -X POST http://localhost:8081/users \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","email":"alice@example.com"}'

# Get all users
curl http://localhost:8081/users

# Get specific user
curl http://localhost:8081/users/1

# View metrics
curl http://localhost:8081/metrics

# Check health
curl http://localhost:8081/health
```

## 📊 Using Prometheus

1. Open http://localhost:9090
2. Try these queries:
   ```promql
   # Check if services are up
   up
   
   # Request rate
   rate(http_requests_total[5m])
   
   # Request duration (p95)
   histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
   
   # Total users
   users_total
   ```

## 📈 Using Grafana

1. Open http://localhost:3000
2. Login: admin/admin
3. Go to Dashboards → New Dashboard
4. Add panel with queries:
   - `rate(http_requests_total[5m])` - Request rate
   - `http_requests_total` - Total requests
   - `users_total` - User count

## 🛑 Stop Everything

```bash
./stop.sh
```

## 📝 Logs

All logs are in `logs/`:
- `logs/prometheus.log`
- `logs/grafana.log`
- `logs/user-service.log`

## 🔧 Scripts

| Script | Description |
|--------|-------------|
| `setup.sh` | Initial setup (run once) |
| `install-binaries.sh` | Download monitoring binaries |
| `start.sh` | Start all services |
| `stop.sh` | Stop all services |
| `status.sh` | Check service status |

## 📂 Project Structure

```
.
├── config/                 # Configuration files (committed)
│   ├── prometheus/
│   ├── grafana/
│   └── alertmanager/
├── services/              # Microservices (committed)
│   └── user-service/
├── bin/                   # Binaries (downloaded, gitignored)
├── data/                  # Runtime data (gitignored)
├── logs/                  # Log files (gitignored)
├── start.sh              # Control scripts
├── stop.sh
├── status.sh
└── README.md
```

## 🎯 Next Steps

1. **Add more services** - Create order-service, api-gateway
2. **Custom dashboards** - Build Grafana visualizations
3. **Alert rules** - Configure AlertManager notifications
4. **Add Elasticsearch** - For log aggregation
5. **Add Kibana** - For log visualization

## 🐛 Troubleshooting

### Port already in use
```bash
lsof -i :9090  # Find what's using the port
kill -9 <PID>  # Kill the process
```

### PostgreSQL connection failed
```bash
# Check if PostgreSQL is running
pg_isready

# Start PostgreSQL
pg_ctl -D /usr/local/var/postgres start  # macOS
sudo systemctl start postgresql           # Linux
```

### View service logs
```bash
tail -f logs/user-service.log
tail -f logs/prometheus.log
```

## 🤝 Contributing

Feel free to submit issues and pull requests!

## 📄 License

MIT
EOF

cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2024

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            Setup Complete! 🎉                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Lightweight monitoring stack created!${NC}"
echo ""
echo -e "${YELLOW}📦 Size: ~50KB (binaries download on first run)${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Initialize database: ${GREEN}createdb users_db${NC}"
echo -e "  2. Start services: ${GREEN}./start.sh${NC}"
echo -e "  3. Check status: ${GREEN}./status.sh${NC}"
echo ""
echo -e "${BLUE}Ready to push to GitHub! 🚀${NC}"`