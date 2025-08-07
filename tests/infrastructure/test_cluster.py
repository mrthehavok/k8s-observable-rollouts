import pytest
import subprocess
import yaml
from kubernetes import client, config

class TestClusterInfrastructure:

    @pytest.fixture(scope="class")
    def k8s_client(self):
        config.load_kube_config(context="k8s-rollouts")
        return client.CoreV1Api()

    def test_cluster_nodes_ready(self, k8s_client):
        """Test all cluster nodes are in Ready state"""
        nodes = k8s_client.list_node()
        assert len(nodes.items) > 0, "No nodes found in cluster"

        for node in nodes.items:
            conditions = node.status.conditions
            ready_condition = next(
                (c for c in conditions if c.type == "Ready"),
                None
            )
            assert ready_condition is not None, f"Node {node.metadata.name} missing Ready condition"
            assert ready_condition.status == "True", f"Node {node.metadata.name} is not Ready"

    def test_required_namespaces_exist(self, k8s_client):
        """Test all required namespaces exist"""
        required_namespaces = [
            "default", "kube-system", "ingress-nginx",
            "argocd", "monitoring", "sample-app", "argo-rollouts"
        ]

        namespaces = k8s_client.list_namespace()
        existing_namespaces = [ns.metadata.name for ns in namespaces.items]

        for ns in required_namespaces:
            assert ns in existing_namespaces, f"Required namespace '{ns}' not found"

    def test_storage_classes_available(self):
        """Test storage classes are properly configured"""
        v1 = client.StorageV1Api()
        storage_classes = v1.list_storage_class()

        assert len(storage_classes.items) > 0, "No storage classes found"

        # Check for default storage class
        default_sc = next(
            (sc for sc in storage_classes.items
             if sc.metadata.annotations.get("storageclass.kubernetes.io/is-default-class") == "true"),
            None
        )
        assert default_sc is not None, "No default storage class found"

    def test_ingress_controller_running(self, k8s_client):
        """Test NGINX ingress controller is running"""
        pods = k8s_client.list_namespaced_pod(
            namespace="ingress-nginx",
            label_selector="app.kubernetes.io/component=controller"
        )

        assert len(pods.items) > 0, "No ingress controller pods found"

        for pod in pods.items:
            assert pod.status.phase == "Running", f"Ingress pod {pod.metadata.name} not running"

            # Check all containers are ready
            for container_status in pod.status.container_statuses:
                assert container_status.ready, f"Container {container_status.name} not ready"

    def test_dns_resolution(self):
        """Test cluster DNS is working"""
        result = subprocess.run(
            ["kubectl", "run", "dns-test", "--image=busybox:1.28", "--rm", "-i", "--restart=Never", "--",
             "nslookup", "kubernetes.default"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"DNS resolution failed: {result.stderr}"
        assert "kubernetes.default.svc.cluster.local" in result.stdout