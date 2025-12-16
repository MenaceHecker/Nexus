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
