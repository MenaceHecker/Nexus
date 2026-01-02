from flask import Flask, request, jsonify
from prometheus_client import Counter, Histogram, Gauge, generate_latest, REGISTRY
import psycopg2
import time
import logging
import json
import os

## Microservice: User Service
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
