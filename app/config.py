"""Configuration de l'application."""
import os


class Config:
    """Configuration de base."""
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key-change-me')

    DB_HOST = os.getenv('DB_HOST', 'localhost')
    DB_PORT = os.getenv('DB_PORT', '5432')
    DB_NAME = os.getenv('DB_NAME', 'appdb')
    DB_USER = os.getenv('DB_USER', 'appuser')
    DB_PASS = os.getenv('DB_PASSWORD', 'apppass')

    SQLALCHEMY_DATABASE_URI = (
        f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    REDIS_HOST = os.getenv('REDIS_HOST', 'localhost')
    REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))

    APP_VERSION = os.getenv('APP_VERSION', '1.0.0')
    ENVIRONMENT = os.getenv('ENVIRONMENT', 'development')


class TestConfig(Config):
    """Configuration de test."""
    TESTING = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
