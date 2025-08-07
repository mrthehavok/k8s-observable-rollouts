import pytest
import subprocess
import json
import time

class TestPerformance:

    def test_baseline_performance(self):
        """Test application meets baseline performance requirements"""
        # Run k6 load test
        result = subprocess.run(
            "k6 run tests/performance/load-test.js",
            shell=True,
            capture_output=True,
            text=True
        )

        assert result.returncode == 0, f"Load test failed: {result.stderr}"

        # Parse results
        with open("load-test-results.json", "r") as f:
            results = json.load(f)

        # Check thresholds
        metrics = results["metrics"]

        # P95 latency should be under 500ms
        p95_latency = metrics["http_req_duration"]["p(95)"]
        assert p95_latency < 500, f"P95 latency {p95_latency}ms exceeds threshold"

        # Error rate should be under 1%
        error_rate = metrics["http_req_failed"]["rate"]
        assert error_rate < 0.01, f"Error rate {error_rate} exceeds threshold"

    def test_autoscaling_behavior(self):
        """Test HPA scales pods under load"""
        namespace = "sample-app"
        deployment = "sample-api"

        # Get initial replica count
        initial_replicas = self._get_replica_count(namespace, deployment)

        # Generate load
        subprocess.Popen(
            "k6 run --vus 200 --duration 5m tests/performance/load-test.js",
            shell=True
        )

        # Wait for HPA to react
        time.sleep(120)

        # Check if scaled up
        current_replicas = self._get_replica_count(namespace, deployment)
        assert current_replicas > initial_replicas, \
            f"HPA did not scale up (initial: {initial_replicas}, current: {current_replicas})"

        # Wait for load to finish and scale down
        time.sleep(300)

        # Check if scaled back down
        final_replicas = self._get_replica_count(namespace, deployment)
        assert final_replicas <= initial_replicas + 1, \
            f"HPA did not scale down (final: {final_replicas})"

    def _get_replica_count(self, namespace, deployment):
        """Get current replica count for a deployment"""
        result = subprocess.run(
            f"kubectl get deployment {deployment} -n {namespace} "
            "-o jsonpath='{.status.readyReplicas}'",
            shell=True,
            capture_output=True,
            text=True
        )
        return int(result.stdout.strip() or "0")

    def test_resource_limits(self):
        """Test application respects resource limits"""
        # This would monitor resource usage during load test
        # and verify it stays within configured limits
        pass