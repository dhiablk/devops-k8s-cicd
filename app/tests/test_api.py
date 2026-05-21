"""Tests des endpoints API."""
import pytest
from main import create_app, db
from config import TestConfig


@pytest.fixture
def client():
    """Fixture du client de test avec DB en mémoire."""
    app = create_app(TestConfig)
    with app.app_context():
        db.create_all()
    with app.test_client() as client:
        yield client
    with app.app_context():
        db.drop_all()


def test_create_task(client):
    """POST /api/v1/tasks crée une tâche."""
    resp = client.post('/api/v1/tasks', json={
        'title': 'Test Task',
        'description': 'Description de test',
        'priority': 'high'
    })
    assert resp.status_code == 201
    assert resp.json['title'] == 'Test Task'
    assert resp.json['priority'] == 'high'


def test_create_task_no_title(client):
    """POST /api/v1/tasks sans titre retourne 400."""
    resp = client.post('/api/v1/tasks', json={})
    assert resp.status_code == 400


def test_list_tasks(client):
    """GET /api/v1/tasks retourne la liste."""
    for i in range(3):
        client.post('/api/v1/tasks', json={'title': f'Task {i}'})

    resp = client.get('/api/v1/tasks')
    assert resp.status_code == 200
    assert resp.json['total'] == 3


def test_get_task(client):
    """GET /api/v1/tasks/<id> retourne la tâche."""
    create = client.post('/api/v1/tasks', json={'title': 'Get me'})
    task_id = create.json['id']

    resp = client.get(f'/api/v1/tasks/{task_id}')
    assert resp.status_code == 200
    assert resp.json['title'] == 'Get me'


def test_update_task(client):
    """PUT /api/v1/tasks/<id> met à jour la tâche."""
    create = client.post('/api/v1/tasks', json={'title': 'Old'})
    task_id = create.json['id']

    resp = client.put(f'/api/v1/tasks/{task_id}', json={
        'title': 'Updated',
        'completed': True
    })
    assert resp.status_code == 200
    assert resp.json['title'] == 'Updated'
    assert resp.json['completed'] is True


def test_delete_task(client):
    """DELETE /api/v1/tasks/<id> supprime la tâche."""
    create = client.post('/api/v1/tasks', json={'title': 'Delete me'})
    task_id = create.json['id']

    resp = client.delete(f'/api/v1/tasks/{task_id}')
    assert resp.status_code == 200

    resp = client.get(f'/api/v1/tasks/{task_id}')
    assert resp.status_code == 404


def test_stats(client):
    """GET /api/v1/stats retourne les statistiques."""
    client.post('/api/v1/tasks', json={'title': 'T1'})
    resp = client.get('/api/v1/stats')
    assert resp.status_code == 200
    assert resp.json['total'] == 1
