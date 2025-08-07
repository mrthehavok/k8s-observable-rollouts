from prometheus_client import Counter, Histogram, Gauge, Info, REGISTRY
from prometheus_client import generate_latest
import time
from typing import Dict, Any

class MetricsRegistry:
    def __init__(self):
        # Request metrics
        self.request_count = Counter(
            'http_requests_total',
            'Total HTTP requests',
            ['method', 'endpoint', 'status']
        )

        self.request_duration = Histogram(
            'http_request_duration_seconds',
            'HTTP request duration in seconds',
            ['method', 'endpoint']
        )

        self.request_size = Histogram(
            'http_request_size_bytes',
            'HTTP request size in bytes',
            ['method', 'endpoint']
        )

        self.response_size = Histogram(
            'http_response_size_bytes',
            'HTTP response size in bytes',
            ['method', 'endpoint']
        )

        # Application metrics
        self.error_count = Counter(
            'app_errors_total',
            'Total application errors',
            ['error_type']
        )

        self.active_requests = Gauge(
            'http_requests_active',
            'Number of active HTTP requests'
        )

        # Version info
        self.version_info = Info(
            'app_version',
            'Application version information'
        )

        # Business metrics
        self.business_operations = Counter(
            'business_operations_total',
            'Total business operations',
            ['operation', 'status']
        )

    def initialize(self):
        """Initialize metrics with default values"""
        from app.version import version_info
        self.version_info.info({
            'version': version_info.version,
            'build': version_info.build_number or 'unknown',
            'commit': version_info.git_commit or 'unknown'
        })

    def track_request(self, method: str, endpoint: str, status: int, duration: float,
                     request_size: int, response_size: int):
        """Track HTTP request metrics"""
        self.request_count.labels(method=method, endpoint=endpoint, status=status).inc()
        self.request_duration.labels(method=method, endpoint=endpoint).observe(duration)
        self.request_size.labels(method=method, endpoint=endpoint).observe(request_size)
        self.response_size.labels(method=method, endpoint=endpoint).observe(response_size)

    def track_error(self, error_type: str):
        """Track application errors"""
        self.error_count.labels(error_type=error_type).inc()

    def get_metrics(self) -> bytes:
        """Generate Prometheus metrics"""
        return generate_latest(REGISTRY)

metrics_registry = MetricsRegistry()