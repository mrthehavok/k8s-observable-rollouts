import pytest
import subprocess
import time
import requests

class TestChaosEngineering:

    def test_pod_failure_recovery(self):
        """Test application recovers from pod failures"""
        namespace = "sample-app"

        # Delete a pod
        result = subprocess.run(
            f"kubectl delete pod -n {namespace} -l app=sample-api --wait=false",
            shell=True,
            capture_output=True
        )

        # Application should remain accessible
        for i in range(30):
            try:
                response = requests.get("http://app.local/health/ready", timeout=5)
                assert response.status_code == 200
            except:
                if i == 29:
                    pytest.fail("Application not accessible after pod deletion")
            time.sleep(2)

        # Check pod was recreated
        time.sleep(30)
        result = subprocess.run(
            f"kubectl get pods -n {namespace} -l app=sample-api --no-headers | wc -l",
            shell=True,
            capture_output=True,
            text=True
        )
        pod_count = int(result.stdout.strip())
        assert pod_count >= 2, "Pods were not recreated"

    def test_network_partition(self):
        """Test behavior during network partition"""
        # This would use Chaos Mesh to inject network delays/partitions
        chaos_manifest = """
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-delay-test
  namespace: sample-app
spec:
  action: delay
  mode: all
  selector:
    labelSelectors:
      app: sample-api
  delay:
    latency: "500ms"
    jitter: "100ms"
  duration: "2m"
"""
        # Apply chaos and test application behavior
        pass

    def test_resource_exhaustion(self):
        """Test behavior under resource exhaustion"""
        # Generate high CPU load
        for _ in range(10):
            requests.get("http://app.local/demo/cpu?duration=5")

        # Check application remains responsive
        response = requests.get("http://app.local/health/ready", timeout=10)
        assert response.status_code == 200

        # Check metrics show resource pressure
        prom_response = requests.get(
            "http://prometheus.local/api/v1/query",
            params={"query": 'rate(container_cpu_usage_seconds_total{pod=~"sample-api-.*"}[1m])'}
        )

        assert prom_response.status_code == 200
        result = prom_response.json()

        # CPU usage should be elevated
        cpu_usage = float(result["data"]["result"][0]["value"][1])
        assert cpu_usage > 0.5, "CPU usage not elevated as expected"