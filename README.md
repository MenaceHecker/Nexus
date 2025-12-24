# Monitoring Stack - Learn Observability by Building It

This is a hands-on monitoring stack that helps in modern observability tools by actually using them. Instead of writing vague metrics on Resume and not able to defend them in interviews you can use this tool Nexus for accurate metrics. 

## Why This Project?

I built this because reading documentation is boring. You want to see real metrics flowing through Prometheus, building actual dashboards in Grafana, watching alerts fire when things break and understanding how production monitoring works. 


## What You Get

- **Prometheus** - Collects metrics from your services every 15 seconds
- **Grafana** - Makes those metrics look pretty (and useful)
- **AlertManager** - Yells at you when things go wrong
- **Sample Service** - A Python Flask API that actually does stuff

The best part? Everything runs locally, no cloud accounts needed, and it's small enough to push to GitHub (~50KB before downloading binaries).

## Quick Start (10 Minutes)

### What You Need

- A Mac (Intel or Apple Silicon) or Linux machine
- PostgreSQL installed
- Python 3.8 or higher
- About 100MB of disk space for the monitoring tools

**macOS:**
```bash
brew install postgresql@15
brew services start postgresql@15
```

**Ubuntu/Debian:**
```bash
sudo apt install postgresql
sudo systemctl start postgresql
```

### Let's Go

```bash
# 1. Clone this repo
git clone https://github.com/yourusername/monitoring-stack.git
cd monitoring-stack

# 2. Set up the database (one-time thing)
createdb users_db
createuser -s postgres

# 3. Start everything
./start.sh

# Give it a few seconds to boot up...
sleep 5

# 4. Check if it worked
./status.sh
```

You should see all green checkmarks ✅. If not, check out `SETUP_COMMANDS.md` for troubleshooting.

## Your First Test

Let's create some users and watch the metrics flow:

```bash
# Create a user
curl -X POST http://localhost:8081/users \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","email":"alice@example.com"}'

# See all users
curl http://localhost:8081/users

# Check the metrics
curl http://localhost:8081/metrics
```

Now open **Prometheus** (http://localhost:9090) and type `users_total` in the query box. You should see the number 1. Magic! 🎉

## The Fun Part - Exploring

### Prometheus (http://localhost:9090)

This is where all your metrics live. Try these queries:

```promql
# How many requests per second?
rate(http_requests_total[5m])

# How long do requests take? (95th percentile)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Are all my services up?
up
```

Click around, try different time ranges, see what you discover.

### Grafana (http://localhost:3000)

**Login:** admin / admin

This is where you make pretty dashboards. Here's how to make your first one:

1. Click the **+** icon → New Dashboard
2. Click **Add visualization**
3. Select **Prometheus**
4. Type a query like `users_total`
5. Click **Apply**

Boom. You just created a dashboard panel. Now add more!

**Pro tip:** Try the Explore feature (compass icon) to play with queries before adding them to dashboards.

## Making It Actually Interesting

### Generate Some Traffic

Let's make those graphs actually move:

```bash
# Create a bunch of users
for i in {1..10}; do
  curl -X POST http://localhost:8081/users \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"user$i\",\"email\":\"user$i@example.com\"}"
  sleep 0.5
done

# Hit the API a bunch of times
for i in {1..50}; do
  curl -s http://localhost:8081/users > /dev/null
  sleep 0.2
done
```

Now check Prometheus and Grafana - your graphs should be way more interesting!

## When Things Break (They Will)

**Nothing shows up in status.sh?**
- Check the logs: `tail -f logs/*.log`
- Maybe PostgreSQL isn't running: `pg_isready`
- Ports might be in use: `lsof -i :9090`

**"Bad CPU type" error?**
- You're on Apple Silicon but downloaded Intel binaries
- Check `SETUP_COMMANDS.md` for the fix

**Python modules not found?**
- The virtual environment might be broken
- Check `SETUP_COMMANDS.md` for how to rebuild it

Full troubleshooting guide is in `SETUP_COMMANDS.md`.

## What's Actually Happening?

Every 15 seconds:
1. Prometheus scrapes `/metrics` from your User Service
2. It stores these time-series in a database
3. Grafana queries Prometheus to show you pretty graphs
4. AlertManager watches for problems and would notify you (if configured)

Your User Service is instrumented with Prometheus client library, so every HTTP request gets counted and timed automatically.

## Daily Usage

**Starting your day:**
```bash
./start.sh
./status.sh
```

**Checking what's happening:**
```bash
tail -f logs/user-service.log
```

**Wrapping up:**
```bash
./stop.sh
```

## What's Next?

Now that you have this running, you can:

1. **Add More Services** - Build an order service, API gateway, whatever
2. **Create Better Dashboards** - Visualize everything
3. **Setup Real Alerts** - Get Slack notifications when things break
4. **Add Elasticsearch + Kibana** - Aggregate and search logs
5. **Load Test It** - See how it behaves under stress

Each of these teaches you something new about production systems.

## Project Structure

```
.
├── config/              # All configuration files
│   ├── prometheus/      # Prometheus config & alert rules
│   ├── grafana/        # Grafana datasources & settings
│   └── alertmanager/   # Alert routing config
├── services/
│   └── user-service/   # Sample Flask API with metrics
├── bin/                # Downloaded binaries (gitignored)
├── data/               # Where everything stores data (gitignored)
├── logs/               # All service logs (gitignored)
├── start.sh           # Start everything
├── stop.sh            # Stop everything
└── status.sh          # Check if things are running
```

Only config and code goes in git - data and binaries stay local.

## Why These Tools?

**Prometheus** - Industry standard for metrics. Used by everyone from startups to Google. Time-series database that's really good at handling lots of metrics.

**Grafana** - Makes metrics actually useful. If Prometheus is your data warehouse, Grafana is your BI tool. Beautiful dashboards, great UX.

**AlertManager** - Handles the "oh crap something's wrong" part. Deduplicates alerts, routes them to the right people, has cool features like silencing during maintenance.

## Contributing

Found a bug? Have an idea? PRs welcome! This is meant to be a learning resource, so if something is confusing or broken, let's fix it.

## Learning Resources

Want to go deeper?

- **Prometheus docs:** https://prometheus.io/docs/
- **Grafana tutorials:** https://grafana.com/tutorials/
- **PromQL (query language):** https://prometheus.io/docs/prometheus/latest/querying/basics/
- **This repo's command guide:** `SETUP_COMMANDS.md`

## Notes

- This is for learning, not production (yet!)
- Binaries download on first run (~100MB)
- Everything runs on your machine
- No cloud services needed
- No data leaves your computer

## License

MIT - Do whatever you want with it. Learn, break things, build cool stuff.

---

**Having issues?** Check `SETUP_COMMANDS.md` for detailed troubleshooting, or open an issue.

**Want to chat about monitoring?** Open a discussion!

Built with ☕ and many late-night debugging sessions.