import os
import logging
from flask import Flask, jsonify, request
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timezone

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-key')
app.config['SQLALCHEMY_DATABASE_URI'] = (
    f"postgresql://"
    f"{os.getenv('DB_USER', 'appuser')}:"
    f"{os.getenv('DB_PASSWORD', 'apppass')}@"
    f"{os.getenv('DB_HOST', 'localhost')}:"
    f"{os.getenv('DB_PORT', '5432')}/"
    f"{os.getenv('DB_NAME', 'appdb')}"
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Mode TEST
if os.getenv('TESTING', 'false').lower() == 'true':
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    app.config['TESTING'] = True

db = SQLAlchemy(app)

app.redis = None
if not app.config.get('TESTING'):
    try:
        import redis
        r = redis.Redis(
            host=os.getenv('REDIS_HOST', 'localhost'),
            port=int(os.getenv('REDIS_PORT', 6379)),
            decode_responses=True,
            socket_connect_timeout=3
        )
        r.ping()
        app.redis = r
        logger.info("Redis OK")
    except Exception as e:
        logger.warning(f"Redis: {e}")


class Task(db.Model):
    __tablename__ = 'tasks'
    id          = db.Column(db.Integer, primary_key=True)
    title       = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, default='')
    completed   = db.Column(db.Boolean, default=False)
    priority    = db.Column(db.String(20), default='medium')
    created_at  = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    def to_dict(self):
        return {
            'id':          self.id,
            'title':       self.title,
            'description': self.description,
            'completed':   self.completed,
            'priority':    self.priority,
            'created_at':  self.created_at.isoformat()
        }


if not app.config.get('TESTING'):
    with app.app_context():
        db.create_all()
        logger.info("Tables creees")


@app.route('/live')
def live():
    return jsonify({'alive': True}), 200


@app.route('/ready')
def ready():
    try:
        db.session.execute(db.text('SELECT 1'))
        return jsonify({'ready': True}), 200
    except Exception:
        return jsonify({'ready': False}), 503


@app.route('/health')
def health():
    result = {
        'status':      'healthy',
        'version':     os.getenv('APP_VERSION', '1.0.0'),
        'environment': os.getenv('ENVIRONMENT', 'dev'),
        'checks':      {}
    }

    try:
        db.session.execute(db.text('SELECT 1'))
        result['checks']['database'] = 'up'
    except Exception as e:
        result['checks']['database'] = f'down: {e}'
        result['status'] = 'unhealthy'

    try:
        if app.redis:
            app.redis.ping()
            result['checks']['redis'] = 'up'
        else:
            result['checks']['redis'] = 'disabled'
    except Exception as e:
        result['checks']['redis'] = f'down: {e}'

    code = 200 if result['status'] == 'healthy' else 503
    return jsonify(result), code


@app.route('/api/v1/tasks', methods=['GET'])
def list_tasks():
    tasks = Task.query.order_by(Task.created_at.desc()).all()
    return jsonify({
        'tasks': [t.to_dict() for t in tasks],
        'total': len(tasks)
    }), 200


@app.route('/api/v1/tasks', methods=['POST'])
def create_task():
    data = request.get_json()
    if not data or not data.get('title'):
        return jsonify({'error': 'title requis'}), 400

    task = Task(
        title=data['title'],
        description=data.get('description', ''),
        priority=data.get('priority', 'medium')
    )
    db.session.add(task)
    db.session.commit()
    return jsonify(task.to_dict()), 201


@app.route('/api/v1/tasks/<int:task_id>', methods=['GET'])
def get_task(task_id):
    task = db.get_or_404(Task, task_id)
    return jsonify(task.to_dict()), 200


@app.route('/api/v1/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    task = db.get_or_404(Task, task_id)
    data = request.get_json()
    if not data:
        return jsonify({'error': 'donnees requises'}), 400

    task.title       = data.get('title', task.title)
    task.description = data.get('description', task.description)
    task.completed   = data.get('completed', task.completed)
    task.priority    = data.get('priority', task.priority)
    db.session.commit()
    return jsonify(task.to_dict()), 200


@app.route('/api/v1/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    task = db.get_or_404(Task, task_id)
    db.session.delete(task)
    db.session.commit()
    return jsonify({'message': f'tache {task_id} supprimee'}), 200


@app.route('/api/v1/stats', methods=['GET'])
def stats():
    total     = Task.query.count()
    completed = Task.query.filter_by(completed=True).count()
    return jsonify({
        'total':           total,
        'completed':       completed,
        'pending':         total - completed,
        'completion_rate': round((completed / total * 100) if total else 0, 2)
    }), 200


if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    logger.info(f"Flask sur http://0.0.0.0:{port}")
    app.run(
        host='0.0.0.0',
        port=port,
        debug=False,
        use_reloader=False
    )
