"""Tests des endpoints de health check."""
import pytest
from main import create_app
from config import TestConfig


@pytest.fixture
def client():
    """Fixture du client de test."""
    app = create_app(TestConfig)
    with app.test_client() as client:
        yield client


def test_liveness(client):
    """L'endpoint /live doit répondre 200."""
    resp = client.get('/live')
    assert resp.status_code == 200
    assert resp.json['alive'] is True


def test_readiness(client):
    """L'endpoint /ready doit répondre 200 avec SQLite en test."""
    resp = client.get('/ready')
    assert resp.status_code == 200


def test_health(client):
    """L'endpoint /health retourne les infos système."""
    resp = client.get('/health')
    assert resp.status_code == 200
    data = resp.json
    assert 'version' in data
    assert 'checks' in data
