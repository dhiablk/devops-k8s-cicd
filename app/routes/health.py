import platform
import psutil
from flask import Blueprint, jsonify, current_app
from extensions import db

health_bp = Blueprint('health', __name__)


@health_bp.route('/health', methods=['GET'])
def health():
    checks = {
        'status': 'healthy',
        'version': current_app.config['APP_VERSION'],
        'environment': current_app.config['ENVIRONMENT'],
        'checks': {}
    }

    try:
        db.session.execute(db.text('SELECT 1'))
        checks['checks']['database'] = {'status': 'up'}
    except Exception as e:
        checks['checks']['database'] = {'status': 'down', 'error': str(e)}
        checks['status'] = 'unhealthy'

    try:
        if current_app.redis:
            current_app.redis.ping()
            checks['checks']['redis'] = {'status': 'up'}
        else:
            checks['checks']['redis'] = {'status': 'disabled'}
    except Exception as e:
        checks['checks']['redis'] = {'status': 'down', 'error': str(e)}

    checks['system'] = {
        'hostname': platform.node(),
        'cpu_percent': psutil.cpu_percent(),
        'memory_percent': psutil.virtual_memory().percent
    }

    status_code = 200 if checks['status'] == 'healthy' else 503
    return jsonify(checks), status_code


@health_bp.route('/ready', methods=['GET'])
def ready():
    try:
        db.session.execute(db.text('SELECT 1'))
        return jsonify({'ready': True}), 200
    except Exception:
        return jsonify({'ready': False}), 503


@health_bp.route('/live', methods=['GET'])
def live():
    return jsonify({'alive': True}), 200