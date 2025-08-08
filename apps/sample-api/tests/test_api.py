import pytest
from fastapi import status


def test_root_endpoint(client):
    """Test root endpoint returns 200"""
    response = client.get("/")
    assert response.status_code == status.HTTP_200_OK
    assert "text/html" in response.headers["content-type"]

def test_health_live(client):
    """Test liveness probe"""
    response = client.get("/health/live")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["status"] == "healthy"
    assert "version" in data

def test_health_ready(client):
    """Test readiness probe"""
    response = client.get("/health/ready")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["status"] == "ready"
    assert "checks" in data

def test_version_endpoint(client):
    """Test version endpoint"""
    response = client.get("/api/version")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "version" in data
    assert "environment" in data

def test_metrics_endpoint(client):
    """Test Prometheus metrics endpoint"""
    response = client.get("/metrics")
    assert response.status_code == status.HTTP_200_OK
    assert "text/plain" in response.headers["content-type"]
    assert "http_requests_total" in response.text

def test_slow_endpoint(client, mock_settings):
    """Test slow endpoint with custom delay"""
    mock_settings(ENABLE_SLOW_ENDPOINT=True)
    response = client.get("/demo/slow?delay=1")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["delay"] == 1

def test_error_endpoint(client):
    """Test error simulation endpoint"""
    # Should succeed with 0% error rate
    response = client.get("/demo/error?rate=0")
    assert response.status_code == status.HTTP_200_OK

    # Should fail with 100% error rate
    response = client.get("/demo/error?rate=100")
    assert response.status_code == status.HTTP_500_INTERNAL_SERVER_ERROR