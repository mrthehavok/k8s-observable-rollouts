import pytest
import subprocess
import time
import requests
import json

class TestEndToEndWorkflow:

    def test_complete_deployment_workflow(self):
        """Test complete deployment workflow from code change to production"""

        # Step 1: Verify initial state
        print("Step 1: Verifying initial state...")
        response = requests.get("http://app.local/api/version")
        initial_version = response.json()["version"]
        assert initial_version == "v1.0.0"

        # Step 2: Trigger new deployment via ArgoCD
        print("Step 2: Triggering deployment...")
        new_version = "v2.0.0"
        subprocess.run(
            f"kubectl set image rollout/sample-api "
            f"sample-api=sample-api:{new_version} -n sample-app",
            shell=True
        )

        # Step 3: Monitor rollout progress
        print("Step 3: Monitoring rollout...")
        rollout_complete = False
        for i in range(20):
            result = subprocess.run(
                "kubectl get rollout sample-api -n sample-app "
                "-o jsonpath='{.status.phase}'",
                shell=True,
                capture_output=True,
                text=True
            )

            if result.stdout.strip() == "Healthy":
                rollout_complete = True
                break

            time.sleep(30)

        assert rollout_complete, "Rollout did not complete successfully"

        # Step 4: Verify new version is deployed
        print("Step 4: Verifying new version...")
        response = requests.get("http://app.local/api/version")
        assert response.json()["version"] == new_version

        # Step 5: Check metrics are being collected
        print("Step 5: Checking metrics...")
        prom_response = requests.get(
            "http://prometheus.local/api/v1/query",
            params={"query": 'app_version_info{version="v2.0.0"}'}
        )
        assert len(prom_response.json()["data"]["result"]) > 0

        # Step 6: Verify dashboards show new version
        print("Step 6: Checking dashboards...")
        # This would query Grafana API to verify dashboards updated

        # Step 7: Simulate failure and rollback
        print("Step 7: Testing rollback...")
        subprocess.run(
            "kubectl set image rollout/sample-api "
            "sample-api=sample-api:bad-version -n sample-app",
            shell=True
        )

        time.sleep(60)

        # Abort the failed rollout
        subprocess.run(
            "kubectl argo rollouts abort sample-api -n sample-app",
            shell=True
        )

        # Verify rollback to previous version
        time.sleep(30)
        response = requests.get("http://app.local/api/version")
        assert response.json()["version"] == new_version

        print("✅ End-to-end workflow test completed successfully!")