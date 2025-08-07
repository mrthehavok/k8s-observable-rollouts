import pytest
import concurrent.futures
import requests

class TestMultiComponentIntegration:

    def test_all_components_integrated(self):
        """Test all components work together"""
        results = {}

        def check_component(name, check_func):
            try:
                check_func()
                results[name] = "✅ Passed"
            except Exception as e:
                results[name] = f"❌ Failed: {str(e)}"

        # Define component checks
        checks = {
            "Application API": lambda: self._check_api(),
            "ArgoCD Sync": lambda: self._check_argocd(),
            "Prometheus Metrics": lambda: self._check_prometheus(),
            "Grafana Dashboards": lambda: self._check_grafana(),
            "Argo Rollouts": lambda: self._check_rollouts(),
            "Ingress Routing": lambda: self._check_ingress(),
            "Alerting": lambda: self._check_alerting()
        }

        # Run checks in parallel
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = {
                executor.submit(check_component, name, func): name
                for name, func in checks.items()
            }
            concurrent.futures.wait(futures)

        # Print results
        print("\n=== Integration Test Results ===")
        for component, status in results.items():
            print(f"{component}: {status}")

        # Assert all passed
        failures = [c for c, s in results.items() if "Failed" in s]
        assert len(failures) == 0, f"Components failed: {failures}"

    def _check_api(self):
        response = requests.get("http://app.local/api/version")
        assert response.status_code == 200

    def _check_argocd(self):
        # Check ArgoCD API
        response = requests.get("https://argocd.local/api/v1/applications",
                              verify=False)
        assert response.status_code in [200, 401]  # 401 if auth required

    def _check_prometheus(self):
        response = requests.get("http://prometheus.local/api/v1/query?query=up")
        assert response.status_code == 200

    def _check_grafana(self):
        response = requests.get("http://grafana.local/api/health")
        assert response.status_code == 200

    def _check_rollouts(self):
        # Check rollouts dashboard
        response = requests.get("http://rollouts.local")
        assert response.status_code == 200

    def _check_ingress(self):
        # Check ingress is routing correctly
        response = requests.get("http://app.local",
                              headers={"Host": "app.local"})
        assert response.status_code == 200

    def _check_alerting(self):
        response = requests.get("http://alertmanager.local")
        assert response.status_code == 200