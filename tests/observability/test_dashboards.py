import pytest
import requests

class TestGrafanaDashboards:

    GRAFANA_URL = "http://grafana.local"
    AUTH = ("admin", "admin")  # Use actual credentials

    def test_dashboards_loaded(self):
        """Test all expected dashboards are loaded"""
        response = requests.get(
            f"{self.GRAFANA_URL}/api/search",
            auth=self.AUTH
        )
        assert response.status_code == 200

        dashboards = response.json()
        dashboard_titles = {d["title"] for d in dashboards}

        expected_dashboards = [
            "Sample API Dashboard",
            "Argo Rollouts Dashboard",
            "Kubernetes Cluster Monitoring",
            "NGINX Ingress Controller"
        ]

        for expected in expected_dashboards:
            assert expected in dashboard_titles, f"Dashboard '{expected}' not found"

    def test_datasources_configured(self):
        """Test datasources are properly configured"""
        response = requests.get(
            f"{self.GRAFANA_URL}/api/datasources",
            auth=self.AUTH
        )
        assert response.status_code == 200

        datasources = response.json()
        ds_types = {ds["type"] for ds in datasources}

        assert "prometheus" in ds_types, "Prometheus datasource not found"

        # Test datasource connectivity
        for ds in datasources:
            if ds["type"] == "prometheus":
                test_response = requests.get(
                    f"{self.GRAFANA_URL}/api/datasources/{ds['id']}/health",
                    auth=self.AUTH
                )
                assert test_response.status_code == 200

    def test_alerts_configured(self):
        """Test Grafana alerts are configured"""
        response = requests.get(
            f"{self.GRAFANA_URL}/api/v1/provisioning/alert-rules",
            auth=self.AUTH
        )

        # Grafana 8+ unified alerting
        if response.status_code == 200:
            alerts = response.json()
            assert len(alerts) > 0, "No alerts configured"