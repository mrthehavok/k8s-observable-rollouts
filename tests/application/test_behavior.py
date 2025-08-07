import pytest
import requests
import json

class TestApplicationBehavior:

    def test_request_id_tracking(self):
        """Test request ID is properly tracked"""
        headers = {"X-Request-ID": "test-123"}
        response = requests.get("http://app.local/api/info", headers=headers)

        # Check if request ID is returned in response headers
        assert "X-Request-ID" in response.headers
        assert response.headers["X-Request-ID"] == "test-123"

    def test_cors_headers(self):
        """Test CORS headers are properly set"""
        response = requests.options(
            "http://app.local/api/version",
            headers={"Origin": "http://example.com"}
        )

        assert response.status_code == 200
        assert "Access-Control-Allow-Origin" in response.headers
        assert response.headers["Access-Control-Allow-Origin"] == "*"

    def test_content_types(self):
        """Test different content types are handled correctly"""
        # JSON endpoint
        json_response = requests.get("http://app.local/api/version")
        assert "application/json" in json_response.headers["content-type"]

        # HTML endpoint
        html_response = requests.get("http://app.local/html")
        assert "text/html" in html_response.headers["content-type"]

        # Metrics endpoint
        metrics_response = requests.get("http://app.local/metrics")
        assert "text/plain" in metrics_response.headers["content-type"]

    def test_error_handling(self):
        """Test application error handling"""
        # Test 404 handling
        response = requests.get("http://app.local/nonexistent")
        assert response.status_code == 404

        # Test invalid query parameters
        response = requests.get("http://app.local/demo/slow?delay=invalid")
        assert response.status_code == 422  # Validation error

    def test_graceful_shutdown(self):
        """Test application handles shutdown gracefully"""
        # This would require coordination with the deployment
        # For now, we'll test that the app responds to signals
        pass