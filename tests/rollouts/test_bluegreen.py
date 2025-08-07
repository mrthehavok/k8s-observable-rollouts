import pytest
import subprocess
import time
import requests

class TestBlueGreenDeployment:

    def get_rollout_status(self, name, namespace):
        """Get rollout status"""
        result = subprocess.run(
            f"kubectl get rollout {name} -n {namespace} -o json",
            shell=True,
            capture_output=True,
            text=True
        )
        return json.loads(result.stdout)

    def test_bluegreen_deployment(self):
        """Test blue/green deployment workflow"""
        namespace = "sample-app"
        rollout_name = "sample-api"

        # Update image to trigger rollout
        subprocess.run(
            f"kubectl set image rollout/{rollout_name} "
            f"sample-api=sample-api:v2.0.0 -n {namespace}",
            shell=True
        )

        # Wait for preview service to be ready
        time.sleep(30)

        # Check preview service is serving new version
        preview_response = requests.get("http://app.local",
                                      headers={"Host": "preview.app.local"})
        assert "v2.0.0" in preview_response.text

        # Check active service still serves old version
        active_response = requests.get("http://app.local")
        assert "v1.0.0" in active_response.text

        # Promote rollout
        subprocess.run(
            f"kubectl argo rollouts promote {rollout_name} -n {namespace}",
            shell=True
        )

        # Wait for promotion
        time.sleep(30)

        # Check active service now serves new version
        active_response = requests.get("http://app.local")
        assert "v2.0.0" in active_response.text

    def test_bluegreen_rollback(self):
        """Test blue/green rollback"""
        namespace = "sample-app"
        rollout_name = "sample-api"

        # Trigger bad deployment
        subprocess.run(
            f"kubectl set image rollout/{rollout_name} "
            f"sample-api=sample-api:bad-version -n {namespace}",
            shell=True
        )

        # Wait for rollout to detect failure
        time.sleep(60)

        # Abort rollout
        subprocess.run(
            f"kubectl argo rollouts abort {rollout_name} -n {namespace}",
            shell=True
        )

        # Verify rollback
        status = self.get_rollout_status(rollout_name, namespace)
        assert status["status"]["phase"] == "Healthy"
        assert status["status"]["abort"] == True

    def test_analysis_during_bluegreen(self):
        """Test analysis runs during blue/green deployment"""
        # This test would verify analysis templates are executed
        # and affect the rollout decision
        pass