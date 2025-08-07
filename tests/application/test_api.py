import pytest
import requests
import time
from concurrent.futures import ThreadPoolExecutor

class TestSampleAPI:

    BASE_URL = "http://app.local"

    def test_root_endpoint(self):
        """Test root endpoint returns HTML"""
        response = requests.get(f"{self.BASE_URL}/")
        assert response.status_code == 200
        assert "text/html" in response.headers["content-type"]
        assert "Sample API" in response.text

    def test_health_endpoints(self):
        """Test all health check endpoints"""
        endpoints = ["/health/live", "/health/ready", "/health/startup"]

        for endpoint in endpoints:
            response = requests.get(f"{self.BASE_URL}{endpoint}")
            assert response.status_code == 200
            data = response.json()
            assert "status" in data
            assert "timestamp" in data
            assert "version" in data

    def test_version_endpoint(self):
        """Test version information endpoint"""
        response = requests.get(f"{self.BASE_URL}/api/version")
        assert response.status_code == 200

        data = response.json()
        required_fields = ["version", "build_number", "git_commit", "environment"]
        for field in required_fields:
            assert field in data, f"Missing field: {field}"

    def test_metrics_endpoint(self):
        """Test Prometheus metrics endpoint"""
        response = requests.get(f"{self.BASE_URL}/metrics")
        assert response.status_code == 200
        assert "text/plain" in response.headers["content-type"]

        # Check for expected metrics
        metrics_text = response.text
        expected_metrics = [
            "http_requests_total",
            "http_request_duration_seconds",
            "http_requests_active",
            "app_version_info"
        ]

        for metric in expected_metrics:
            assert metric in metrics_text, f"Metric {metric} not found"

    def test_slow_endpoint(self):
        """Test slow endpoint with custom delay"""
        delay = 2
        start_time = time.time()
        response = requests.get(f"{self.BASE_URL}/demo/slow?delay={delay}")
        end_time = time.time()

        assert response.status_code == 200
        assert (end_time - start_time) >= delay

        data = response.json()
        assert data["delay"] == delay

    def test_error_endpoint(self):
        """Test error simulation endpoint"""
        # Test with 0% error rate (should succeed)
        response = requests.get(f"{self.BASE_URL}/demo/error?rate=0")
        assert response.status_code == 200

        # Test with 100% error rate (should fail)
        response = requests.get(f"{self.BASE_URL}/demo/error?rate=100")
        assert response.status_code == 500

    def test_concurrent_requests(self):
        """Test API handles concurrent requests properly"""
        def make_request(i):
            response = requests.get(f"{self.BASE_URL}/api/info")
            return response.status_code

        with ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request, i) for i in range(50)]
            results = [f.result() for f in futures]

        # All requests should succeed
        assert all(status == 200 for status in results)