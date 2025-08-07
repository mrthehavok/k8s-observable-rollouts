import requests
import pytest
from kubernetes import client, config

class TestComponentHealth:

    @pytest.fixture(scope="class")
    def k8s_apps(self):
        config.load_kube_config(context="k8s-rollouts")
        return client.AppsV1Api()

    def test_argocd_health(self, k8s_apps):
        """Test ArgoCD components are healthy"""
        deployments = [
            "argocd-server",
            "argocd-repo-server",
            "argocd-applicationset-controller",
            "argocd-notifications-controller"
        ]

        for deployment_name in deployments:
            deployment = k8s_apps.read_namespaced_deployment(
                name=deployment_name,
                namespace="argocd"
            )
            assert deployment.status.ready_replicas == deployment.status.replicas, \
                f"{deployment_name} not fully ready"

    def test_prometheus_health(self):
        """Test Prometheus is healthy and scraping targets"""
        # Check Prometheus API
        response = requests.get("http://prometheus.local/api/v1/query?query=up")
        assert response.status_code == 200, "Prometheus API not responding"

        # Check targets are being scraped
        targets_response = requests.get("http://prometheus.local/api/v1/targets")
        assert targets_response.status_code == 200

        targets = targets_response.json()
        active_targets = [t for t in targets["data"]["activeTargets"] if t["health"] == "up"]
        assert len(active_targets) > 0, "No healthy Prometheus targets found"

    def test_grafana_health(self):
        """Test Grafana is accessible and has datasources"""
        # Check Grafana API
        response = requests.get("http://grafana.local/api/health")
        assert response.status_code == 200
        assert response.json()["database"] == "ok"

        # Check datasources (requires auth)
        auth = ("admin", "admin")  # Use actual credentials
        ds_response = requests.get("http://grafana.local/api/datasources", auth=auth)
        assert ds_response.status_code == 200

        datasources = ds_response.json()
        assert len(datasources) > 0, "No datasources configured in Grafana"

        # Check Prometheus datasource exists
        prometheus_ds = next((ds for ds in datasources if ds["type"] == "prometheus"), None)
        assert prometheus_ds is not None, "Prometheus datasource not found"

    def test_rollouts_controller_health(self, k8s_apps):
        """Test Argo Rollouts controller is healthy"""
        deployment = k8s_apps.read_namespaced_deployment(
            name="argo-rollouts",
            namespace="argo-rollouts"
        )
        assert deployment.status.ready_replicas == deployment.status.replicas

        # Check CRDs are installed
        api_client = client.ApiClient()
        custom_api = client.CustomObjectsApi(api_client)

        try:
            custom_api.list_cluster_custom_object(
                group="argoproj.io",
                version="v1alpha1",
                plural="rollouts"
            )
        except Exception as e:
            pytest.fail(f"Rollout CRD not available: {e}")