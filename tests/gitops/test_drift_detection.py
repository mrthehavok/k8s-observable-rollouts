import pytest
import subprocess
import time

class TestDriftDetection:

    def test_drift_detection(self):
        """Test ArgoCD detects configuration drift"""
        # Manually modify a resource
        result = subprocess.run(
            "kubectl patch deployment sample-api -n sample-app "
            "--type merge -p '{\"spec\":{\"replicas\":5}}'",
            shell=True,
            capture_output=True
        )
        assert result.returncode == 0

        # Wait for ArgoCD to detect drift
        time.sleep(30)

        # Check application is out of sync
        result = subprocess.run(
            "kubectl get application sample-api -n argocd "
            "-o jsonpath='{.status.sync.status}'",
            shell=True,
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() == "OutOfSync"

    def test_self_healing(self):
        """Test ArgoCD self-heals drifted resources"""
        # Create drift
        subprocess.run(
            "kubectl patch deployment sample-api -n sample-app "
            "--type merge -p '{\"spec\":{\"replicas\":10}}'",
            shell=True
        )

        # Wait for self-healing (if enabled)
        time.sleep(60)

        # Check resource is healed
        result = subprocess.run(
            "kubectl get deployment sample-api -n sample-app "
            "-o jsonpath='{.spec.replicas}'",
            shell=True,
            capture_output=True,
            text=True
        )

        # Should be back to original value (2)
        assert int(result.stdout.strip()) == 2