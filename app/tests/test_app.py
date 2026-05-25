import os
import pytest

# Forcer le mode TEST AVANT d'importer main
os.environ['TESTING'] = 'true'

import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app, db


@pytest.fixture
def client():
    with app.app_context():
        db.create_all()

    with app.test_client() as c:
        yield c

    with app.app_context():
        db.session.remove()
        db.drop_all()


def test_live(client):
    resp = client.get('/live')
    assert resp.status_code == 200
    assert resp.json['alive'] is True


def test_ready(client):
    resp = client.get('/ready')
    assert resp.status_code == 200


def test_health(client):
    resp = client.get('/health')
    assert 'status' in resp.json
    assert 'checks' in resp.json


def test_list_tasks_empty(client):
    resp = client.get('/api/v1/tasks')
    assert resp.status_code == 200
    assert resp.json['total'] == 0


def test_create_task(client):
    resp = client.post('/api/v1/tasks', json={
        'title': 'Test',
        'priority': 'high'
    })
    assert resp.status_code == 201
    assert resp.json['title'] == 'Test'
    assert resp.json['priority'] == 'high'


def test_create_task_no_title(client):
    resp = client.post('/api/v1/tasks', json={})
    assert resp.status_code == 400


def test_get_task(client):
    create = client.post('/api/v1/tasks', json={'title': 'Get me'})
    task_id = create.json['id']
    resp = client.get(f'/api/v1/tasks/{task_id}')
    assert resp.status_code == 200
    assert resp.json['title'] == 'Get me'


def test_get_task_not_found(client):
    resp = client.get('/api/v1/tasks/9999')
    assert resp.status_code == 404


def test_update_task(client):
    create = client.post('/api/v1/tasks', json={'title': 'Old'})
    task_id = create.json['id']
    resp = client.put(f'/api/v1/tasks/{task_id}', json={
        'title': 'New',
        'completed': True
    })
    assert resp.status_code == 200
    assert resp.json['completed'] is True


def test_delete_task(client):
    create = client.post('/api/v1/tasks', json={'title': 'Del'})
    task_id = create.json['id']
    resp = client.delete(f'/api/v1/tasks/{task_id}')
    assert resp.status_code == 200


def test_stats(client):
    client.post('/api/v1/tasks', json={'title': 'T1'})
    client.post('/api/v1/tasks', json={'title': 'T2'})
    resp = client.get('/api/v1/stats')
    assert resp.status_code == 200
    assert resp.json['total'] == 2
