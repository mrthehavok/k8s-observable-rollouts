import pytest
import subprocess
import time
import requests
from concurrent.futures import ThreadPoolExecutor

class TestCanaryDeployment:

    def test_canary_traffic_split(self):
        """Test traffic is properly split during canary"""
        namespace = "sample-app"
        rollout_name = "sample-api"

        # Configure for canary strategy
        subprocess.run(
            f"kubectl patch rollout {rollout_name} -n {namespace} "
            "--type merge -p '{\"spec\":{\"strategy\":{\"canary\":{}}}}'",
            shell=True
        )

        # Trigger canary deployment
        subprocess.run(
            f"kubectl set image rollout/{rollout_name} "
            f"sample-api=sample-api:v2.0.0 -n {namespace}",
            shell=True
        )

        # Wait for canary to start (20% traffic)
        time.sleep(60)

        # Make 100 requests and check version distribution
        def make_request():
            response = requests.get("http://app.local/api/version")
            return response.json()["version"]

        with ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request) for _ in range(100)]
            versions = [f.result() for f in futures]

        # Count versions
        v1_count = versions.count("v1.0.0")
        v2_count = versions.count("v2.0.0")

        # Should be approximately 80/20 split
        assert 70 <= v1_count <= 90, f"V1 count {v1_count} not in expected range"
        assert 10 <= v2_count <= 30, f"V2 count {v2_count} not in expected range"

    def test_canary_promotion_steps(self):
        """Test canary proceeds through all steps"""
        namespace = "sample-app"
        rollout_name = "sample-api"

        # Monitor rollout steps
        steps_completed = []

        # Start deployment
        subprocess.run(
            f"kubectl set image rollout/{rollout_name} "
            f"sample-api=sample-api:v2.0.0 -n {namespace}",
            shell=True
        )

        # Monitor progress
        for i in range(20):  # Check for 10 minutes
            result = subprocess.run(
                f"kubectl get rollout {rollout_name} -n {namespace} "
                "-o jsonpath='{.status.currentStepIndex}'",
                shell=True,
                capture_output=True,
                text=True
            )

            current_step = int(result.stdout.strip() or "0")
            if current_step not in steps_completed:
                steps_completed.append(current_step)

            # Check if rollout completed
            status_result = subprocess.run(
                f"kubectl get rollout {rollout_name} -n {namespace} "
                "-o jsonpath='{.status.phase}'",
                shell=True,
                capture_output=True,
                text=True
            )

            if status_result.stdout.strip() == "Healthy":
                break

            time.sleep(30)

        # Verify all steps were executed
        assert len(steps_completed) >= 3, "Not all canary steps were executed"

    def test_canary_analysis_failure(self):
        """Test canary aborts on analysis failure"""
        # This test would inject failures to trigger analysis failure
        # and verify the canary is aborted
        pass