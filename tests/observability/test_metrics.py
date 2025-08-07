import pytest
import requests
import time

class TestMetricsCollection:

    PROMETHEUS_URL = "http://prometheus.local"

    def query_prometheus(self, query):
        """Execute Prometheus query"""
        response = requests.get(
            f"{self.PROMETHEUS_URL}/api/v1/query",
            params={"query": query}
        )
        assert response.status_code == 200
        return response.json()

    def test_application_metrics_collected(self):
        """Test application metrics are being collected"""
        metrics = [
            "http_requests_total",
            "http_request_duration_seconds_bucket",
            "http_requests_active",
            "app_version_info"
        ]

        for metric in metrics:
            result = self.query_prometheus(f'{metric}{{app_kubernetes_io_name="sample-api"}}')
            assert result["status"] == "success"
            assert len(result["data"]["result"]) > 0, f"No data for metric {metric}"

    def test_infrastructure_metrics_collected(self):
        """Test infrastructure metrics are being collected"""
        queries = [
            'up{job="kubernetes-nodes"}',
            'node_cpu_seconds_total',
            'node_memory_MemAvailable_bytes',
            'container_cpu_usage_seconds_total'
        ]

        for query in queries:
            result = self.query_prometheus(query)
            assert result["status"] == "success"
            assert len(result["data"]["result"]) > 0, f"No data for query {query}"

    def test_rollout_metrics_collected(self):
        """Test Argo Rollouts metrics are collected"""
        rollout_metrics = [
            "rollout_info",
            "rollout_phase",
            "analysis_run_info",
            "analysis_run_metric_phase"
        ]

        for metric in rollout_metrics:
            result = self.query_prometheus(metric)
            # These might be empty if no rollouts are active
            assert result["status"] == "success"

    def test_servicemonitors_working(self):
        """Test ServiceMonitors are properly configured"""
        # Check targets page
        response = requests.get(f"{self.PROMETHEUS_URL}/api/v1/targets")
        assert response.status_code == 200

        targets = response.json()["data"]["activeTargets"]

        # Check expected targets are present
        expected_jobs = [
            "sample-api",
            "argocd-metrics",
            "argo-rollouts-metrics",
            "kubernetes-nodes",
            "kubernetes-pods"
        ]

        active_jobs = {target["labels"]["job"] for target in targets}

        for job in expected_jobs:
            assert job in active_jobs, f"Job {job} not found in active targets"