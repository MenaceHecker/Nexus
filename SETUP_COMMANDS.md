# Complete Setup Commands & Troubleshooting Guide

## Initial Setup (One-Time)

### 1. Create Project Directory
```bash
# Create a fresh directory for the project
cd ~
mkdir monitoring-project
cd monitoring-project
```

### 2. Run Setup Script
```bash
# Save the setup.sh script and run it
chmod +x setup.sh
./setup.sh
```

**What this does:**
- Creates directory structure (config/, services/, logs/, data/)
- Creates all configuration files for Prometheus, Grafana, AlertManager
- Sets up the User Service Python application
- Creates control scripts (start.sh, stop.sh, status.sh)
- Creates .gitignore for GitHub

---

## Installing Prerequisites

### Install PostgreSQL

**On macOS:**
```bash
brew install postgresql@15
brew services start postgresql@15
```

**On Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
sudo systemctl start postgresql
```

### Create Database
```bash
# Create the users database
createdb users_db

# Verify it was created
psql -l | grep users_db

# Create postgres user (if needed)
createuser -s postgres

# Set password for postgres user
psql -d postgres -c "ALTER USER postgres PASSWORD 'postgres';"

# Verify users exist
psql -d users_db -c "\du"
```

---

## Installing Binaries (Apple Silicon Mac)

### For Apple Silicon (M1/M2/M3 Macs)

```bash
# Create bin directory
mkdir -p bin
cd bin

# Download Prometheus (ARM64)
curl -sL "https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.darwin-arm64.tar.gz" | tar xz --strip-components=1 prometheus-2.45.0.darwin-arm64/prometheus

# Download AlertManager (ARM64)
curl -sL "https://github.com/prometheus/alertmanager/releases/download/v0.26.0/alertmanager-0.26.0.darwin-arm64.tar.gz" | tar xz --strip-components=1 alertmanager-0.26.0.darwin-arm64/alertmanager

# Install Grafana via Homebrew (easier for Mac)
brew install grafana

# Create symlink for Grafana
ln -sf /opt/homebrew/bin/grafana-server grafana-server

# Verify installations
cd ..
./bin/prometheus --version
./bin/alertmanager --version
./bin/grafana-server --version
```

### For Intel Macs

Replace `darwin-arm64` with `darwin-amd64` in the URLs above.

### For Linux

Replace `darwin-arm64` with `linux-amd64` in the URLs above.

---

## Setting Up Python Virtual Environment

```bash
# Navigate to user service
cd services/user-service

# Remove old venv if it exists and isn't working
rm -rf venv

# Create fresh virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
python -m pip install --upgrade pip

# Install dependencies
pip install flask==3.0.0
pip install prometheus-client==0.19.0
pip install psycopg2-binary==2.9.9

# Verify installation
pip list

# Test imports
python -c "import flask; print('Flask OK')"
python -c "import psycopg2; print('psycopg2 OK')"
python -c "from prometheus_client import Counter; print('Prometheus client OK')"

# Deactivate and return to project root
deactivate
cd ../..
```

---

## Creating Grafana Configuration

```bash
# Create Grafana config file
cat > config/grafana/grafana.ini << 'EOF'
[paths]
data = data/grafana
logs = logs
plugins = data/grafana/plugins
provisioning = config/grafana/provisioning

[server]
http_port = 3000

[security]
admin_user = admin
admin_password = admin

[users]
allow_sign_up = false
EOF
```

---

## Starting and Stopping Services

### Start All Services
```bash
./start.sh
```

**What this does:**
- Starts Prometheus on port 9090
- Starts Grafana on port 3000
- Starts AlertManager on port 9093
- Starts User Service on port 8081

### Check Service Status
```bash
./status.sh
```

**Expected output:**
```
✅ Prometheus (port 9090)
✅ Grafana (port 3000)
✅ AlertManager (port 9093)
✅ User Service (port 8081)
```

### Stop All Services
```bash
./stop.sh
```

### View Logs
```bash
# View all logs
tail -f logs/*.log

# View specific service logs
tail -f logs/prometheus.log
tail -f logs/grafana.log
tail -f logs/user-service.log
tail -f logs/alertmanager.log

# View last 50 lines of a log
tail -50 logs/user-service.log
```

---

## Testing the User Service

### Health Check
```bash
curl http://localhost:8081/health
```

**Expected response:**
```json
{"status":"healthy","service":"user-service"}
```

### Create Users
```bash
# Create first user
curl -X POST http://localhost:8081/users \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","email":"alice@example.com"}'

# Create second user
curl -X POST http://localhost:8081/users \
  -H "Content-Type: application/json" \
  -d '{"username":"bob","email":"bob@example.com"}'

# Create third user
curl -X POST http://localhost:8081/users \
  -H "Content-Type: application/json" \
  -d '{"username":"charlie","email":"charlie@example.com"}'
```

**Expected response:**
```json
{"id":1,"username":"alice","email":"alice@example.com"}
```

### Get All Users
```bash
curl http://localhost:8081/users
```

**Expected response:**
```json
{
  "users": [
    {"id":1,"username":"alice","email":"alice@example.com","created_at":"2024-12-24 ..."},
    {"id":2,"username":"bob","email":"bob@example.com","created_at":"2024-12-24 ..."},
    {"id":3,"username":"charlie","email":"charlie@example.com","created_at":"2024-12-24 ..."}
  ],
  "count": 3
}
```

### Get Specific User
```bash
curl http://localhost:8081/users/1
```

### View Prometheus Metrics
```bash
curl http://localhost:8081/metrics
```

This shows metrics like:
- `http_requests_total` - Total number of HTTP requests
- `http_request_duration_seconds` - Request duration histogram
- `users_total` - Current number of users in database

---

## Using Prometheus

### Open Prometheus UI
```bash
open http://localhost:9090
```

### Useful Prometheus Queries

**Check if all services are up:**
```promql
up
```

**Request rate (requests per second):**
```promql
rate(http_requests_total[5m])
```

**Request rate by endpoint:**
```promql
sum(rate(http_requests_total[5m])) by (endpoint)
```

**Total requests by status code:**
```promql
sum(http_requests_total) by (status)
```

**Current number of users:**
```promql
users_total
```

**95th percentile request duration:**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

**Error rate (5xx responses):**
```promql
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
```

---

## Using Grafana

### Open Grafana UI
```bash
open http://localhost:3000
```

### Login
- **Username:** admin
- **Password:** admin
- Skip password change or set a new password

### Create Your First Dashboard

1. Click the **+** icon in the left sidebar
2. Select **Dashboard**
3. Click **Add visualization**
4. Select **Prometheus** as data source
5. Enter a query (e.g., `users_total`)
6. Click **Apply**

### Example Dashboard Panels

**Panel 1: Total Users**
```promql
users_total
```
- Visualization: Stat
- Shows current user count

**Panel 2: Request Rate**
```promql
rate(http_requests_total[5m])
```
- Visualization: Graph
- Shows requests per second over time

**Panel 3: Response Time (P95)**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```
- Visualization: Graph
- Shows 95th percentile response time

**Panel 4: Requests by Status Code**
```promql
sum(http_requests_total) by (status)
```
- Visualization: Pie chart
- Shows distribution of HTTP status codes

---

## Generating Test Traffic

### Simple Load Test
```bash
# Send 50 requests with 200ms delay between each
for i in {1..50}; do
  curl -s http://localhost:8081/users > /dev/null
  sleep 0.2
done
```

### Continuous Traffic Generator
```bash
# Run this in a separate terminal
while true; do
  curl -s http://localhost:8081/users > /dev/null
  sleep 1
done
```

### Create Multiple Users
```bash
# Create 10 test users
for i in {1..10}; do
  curl -X POST http://localhost:8081/users \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"user$i\",\"email\":\"user$i@example.com\"}"
  sleep 0.5
done
```

---

## Troubleshooting

### Services Won't Start

**Check if ports are already in use:**
```bash
lsof -i :9090  # Prometheus
lsof -i :3000  # Grafana
lsof -i :9093  # AlertManager
lsof -i :8081  # User Service
```

**Kill process on a port:**
```bash
# Find PID
lsof -i :8081

# Kill it
kill -9 <PID>
```

### Database Connection Issues

**Check if PostgreSQL is running:**
```bash
pg_isready
```

**Start PostgreSQL:**
```bash
# macOS
brew services start postgresql@15

# Linux
sudo systemctl start postgresql
```

**Check database exists:**
```bash
psql -l | grep users_db
```

**Check postgres user exists:**
```bash
psql -d users_db -c "\du"
```

### Python Module Not Found

**Recreate virtual environment:**
```bash
cd services/user-service
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
deactivate
cd ../..
```

### Bad CPU Type Error (Mac)

This happens when you have Intel binaries on Apple Silicon Mac.

**Solution: Download ARM64 binaries**
```bash
# Remove wrong binaries
rm -rf bin/*

# Follow the "Installing Binaries (Apple Silicon Mac)" section above
```

### Grafana Won't Start

**Use Homebrew's Grafana service:**
```bash
brew services start grafana
```

**Check if it's running:**
```bash
curl http://localhost:3000/api/health
```

### View Running Processes

```bash
# See all monitoring processes
ps aux | grep -E 'prometheus|grafana|alertmanager|python'

# See what's listening on ports
lsof -i -P | grep LISTEN | grep -E '9090|3000|9093|8081'
```

---

## Daily Workflow

### Starting Work
```bash
cd ~/monitoring-project  # or wherever you put it
./start.sh
./status.sh  # Verify all services are up
```

### During Development
```bash
# View logs
tail -f logs/user-service.log

# Test changes
curl http://localhost:8081/users

# Check metrics
curl http://localhost:8081/metrics
```

### Ending Work
```bash
./stop.sh
```

---

## Database Operations

### Connect to Database
```bash
psql users_db
```

### Useful SQL Commands
```sql
-- List all users
SELECT * FROM users;

-- Count users
SELECT COUNT(*) FROM users;

-- Delete a user
DELETE FROM users WHERE id = 1;

-- Clear all users
TRUNCATE TABLE users;

-- Exit psql
\q
```

### Backup Database
```bash
pg_dump users_db > backup.sql
```

### Restore Database
```bash
psql users_db < backup.sql
```

---

## Git Commands for GitHub

### Initialize Git Repository
```bash
git init
git add .
git commit -m "Initial commit: Monitoring stack setup"
```

### Create GitHub Repository
1. Go to GitHub.com
2. Click "New repository"
3. Name it (e.g., "monitoring-stack")
4. Don't initialize with README (we already have one)
5. Click "Create repository"

### Push to GitHub
```bash
# Add remote
git remote add origin https://github.com/YOUR_USERNAME/monitoring-stack.git

# Push
git branch -M main
git push -u origin main
```

### Update Repository
```bash
git add .
git commit -m "Update configuration"
git push
```

---

## Common Issues and Solutions

### Issue: "Role postgres does not exist"
**Solution:**
```bash
createuser -s postgres
psql -d postgres -c "ALTER USER postgres PASSWORD 'postgres';"
```

### Issue: "Port already in use"
**Solution:**
```bash
lsof -i :<PORT>
kill -9 <PID>
```

### Issue: "Module not found" for Python packages
**Solution:**
```bash
cd services/user-service
source venv/bin/activate
pip install -r requirements.txt
deactivate
cd ../..
```

### Issue: Services show as ❌ in status check
**Solution:**
```bash
# View logs to see what failed
cat logs/prometheus.log
cat logs/user-service.log

# Usually need to wait a few seconds
sleep 5
./status.sh
```

### Issue: Grafana config error
**Solution:**
```bash
# Make sure config file exists
cat config/grafana/grafana.ini

# Or use Homebrew's Grafana
brew services start grafana
```

---

## Performance Tips

### Monitor Resource Usage
```bash
# CPU and memory usage
top

# Just monitoring processes
top | grep -E 'prometheus|grafana|python'

# Disk space
df -h

# Check data directory size
du -sh data/
```

### Optimize Prometheus Storage
```bash
# Prometheus data retention (default: 30 days)
# Edit start.sh and add to prometheus command:
--storage.tsdb.retention.time=15d  # Keep 15 days instead
```

---

## Next Steps

Once everything is working:

1. **Add More Services** - Create order-service, api-gateway
2. **Build Dashboards** - Create comprehensive Grafana dashboards
3. **Setup Alerts** - Configure Slack/email notifications
4. **Add Elasticsearch** - For advanced log analysis
5. **Add Kibana** - For log visualization
6. **Load Testing** - Use tools like Apache Bench or k6
7. **Production Hardening** - Add authentication, TLS, etc.

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `./start.sh` | Start all services |
| `./stop.sh` | Stop all services |
| `./status.sh` | Check service status |
| `tail -f logs/*.log` | View all logs |
| `createdb users_db` | Create database |
| `psql users_db` | Connect to database |
| `brew services start grafana` | Start Grafana via Homebrew |
| `lsof -i :8081` | Check what's on port 8081 |

---

## Useful URLs

| Service | URL | Purpose |
|---------|-----|---------|
| User Service | http://localhost:8081 | REST API |
| User Service Health | http://localhost:8081/health | Health check |
| User Service Metrics | http://localhost:8081/metrics | Prometheus metrics |
| Prometheus | http://localhost:9090 | Metrics & queries |
| Grafana | http://localhost:3000 | Dashboards (admin/admin) |
| AlertManager | http://localhost:9093 | Alert management |

---

## Support

If you encounter issues:
1. Check the logs: `tail -f logs/*.log`
2. Verify services are running: `./status.sh`
3. Check database: `psql users_db -c "SELECT 1;"`
4. Review this guide for your specific issue
5. Check GitHub issues for similar problems