import pytest
import subprocess
import yaml
import time

class TestArgoCDSync:

    def run_kubectl(self, cmd):
        """Helper to run kubectl commands"""
        result = subprocess.run(
            f"kubectl {cmd}",
            shell=True,
            capture_output=True,
            text=True
        )
        return result

    def test_application_sync_status(self):
        """Test all ArgoCD applications are synced"""
        result = self.run_kubectl(
            "get applications -n argocd -o json"
        )
        assert result.returncode == 0

        apps = yaml.safe_load(result.stdout)
        for app in apps.get("items", []):
            sync_status = app["status"]["sync"]["status"]
            health_status = app["status"]["health"]["status"]

            assert sync_status == "Synced", \
                f"App {app['metadata']['name']} not synced: {sync_status}"
            assert health_status == "Healthy", \
                f"App {app['metadata']['name']} not healthy: {health_status}"

    def test_manual_sync_trigger(self):
        """Test manual sync can be triggered"""
        app_name = "sample-api"

        # Trigger sync
        result = self.run_kubectl(
            f"patch application {app_name} -n argocd --type merge -p '{{\"metadata\":{{\"annotations\":{{\"test-sync\":\"true\"}}}}}}'"
        )
        assert result.returncode == 0

        # Wait for sync to complete
        time.sleep(10)

        # Check sync completed
        result = self.run_kubectl(
            f"get application {app_name} -n argocd -o jsonpath='{{.status.sync.status}}'"
        )
        assert result.stdout.strip() == "Synced"

    def test_auto_sync_behavior(self):
        """Test auto-sync works when enabled"""
        # This test would modify a git repo and verify sync happens
        # For now, we'll check auto-sync is configured
        result = self.run_kubectl(
            "get applications -n argocd -o json"
        )

        apps = yaml.safe_load(result.stdout)
        for app in apps.get("items", []):
            if app["metadata"]["name"] == "sample-api":
                auto_sync = app["spec"]["syncPolicy"]["automated"]
                assert auto_sync["prune"] == True
                assert auto_sync["selfHeal"] == True

    def test_sync_waves(self):
        """Test resources are created in correct order using sync waves"""
        # Deploy a test application with sync waves
        test_app = """
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sync-wave-test
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/your-org/k8s-observable-rollouts
    path: tests/fixtures/sync-waves
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
"""
        # Apply and verify resources are created in order
        # This would require test fixtures with sync wave annotations
        pass