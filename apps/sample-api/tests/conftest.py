import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    """Create a test client for the FastAPI app"""
    with TestClient(app) as client:
        yield client


@pytest.fixture
def mock_settings(monkeypatch):
    """Mock application settings"""

    def _mock_settings(**kwargs):
        for key, value in kwargs.items():
            monkeypatch.setattr(f"app.config.settings.{key}", value)

    return _mock_settings
