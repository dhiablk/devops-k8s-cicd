import json
from flask import Blueprint, request, jsonify, current_app
from extensions import db
from models import Task

api_bp = Blueprint('api', __name__)

CACHE_TTL = 300


def cache_get(key):
    if current_app.redis:
        try:
            data = current_app.redis.get(key)
            return json.loads(data) if data else None
        except Exception:
            return None
    return None


def cache_set(key, data, ttl=CACHE_TTL):
    if current_app.redis:
        try:
            current_app.redis.setex(key, ttl, json.dumps(data))
        except Exception:
            pass


def cache_invalidate(pattern='tasks:*'):
    if current_app.redis:
        try:
            keys = current_app.redis.keys(pattern)
            if keys:
                current_app.redis.delete(*keys)
        except Exception:
            pass


@api_bp.route('/tasks', methods=['GET'])
def list_tasks():
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    cache_key = f"tasks:list:{page}:{per_page}"

    cached = cache_get(cache_key)
    if cached:
        cached['from_cache'] = True
        return jsonify(cached), 200

    pagination = Task.query.order_by(Task.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )

    result = {
        'tasks': [t.to_dict() for t in pagination.items],
        'total': pagination.total,
        'page': page,
        'per_page': per_page,
        'pages': pagination.pages,
        'from_cache': False
    }

    cache_set(cache_key, result)
    return jsonify(result), 200


@api_bp.route('/tasks', methods=['POST'])
def create_task():
    data = request.get_json()

    if not data or not data.get('title'):
        return jsonify({'error': 'Le titre est requis'}), 400

    task = Task(
        title=data['title'],
        description=data.get('description', ''),
        priority=data.get('priority', 'medium')
    )

    db.session.add(task)
    db.session.commit()

    cache_invalidate()
    return jsonify(task.to_dict()), 201


@api_bp.route('/tasks/<int:task_id>', methods=['GET'])
def get_task(task_id):
    cache_key = f"tasks:detail:{task_id}"
    cached = cache_get(cache_key)
    if cached:
        return jsonify(cached), 200

    task = db.get_or_404(Task, task_id)
    result = task.to_dict()

    cache_set(cache_key, result)
    return jsonify(result), 200


@api_bp.route('/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    task = db.get_or_404(Task, task_id)
    data = request.get_json()

    if not data:
        return jsonify({'error': 'Données requises'}), 400

    task.title = data.get('title', task.title)
    task.description = data.get('description', task.description)
    task.completed = data.get('completed', task.completed)
    task.priority = data.get('priority', task.priority)

    db.session.commit()
    cache_invalidate()

    return jsonify(task.to_dict()), 200


@api_bp.route('/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    task = db.get_or_404(Task, task_id)
    db.session.delete(task)
    db.session.commit()

    cache_invalidate()
    return jsonify({'message': f'Tâche {task_id} supprimée'}), 200


@api_bp.route('/stats', methods=['GET'])
def stats():
    total = Task.query.count()
    completed = Task.query.filter_by(completed=True).count()

    return jsonify({
        'total': total,
        'completed': completed,
        'pending': total - completed,
        'completion_rate': round((completed / total * 100) if total > 0 else 0, 2)
    }), 200