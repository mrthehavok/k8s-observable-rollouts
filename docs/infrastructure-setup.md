# Infrastructure Setup Guide

## Overview

This guide provides detailed instructions for setting up the local Kubernetes infrastructure using Minikube with all necessary addons and configurations for our GitOps observable rollouts project.

## Prerequisites

### System Requirements

- **CPU**: Minimum 4 cores (8 recommended)
- **RAM**: Minimum 8GB (16GB recommended)
- **Storage**: 20GB free disk space
- **OS**: Linux, macOS, or Windows with WSL2

### Software Requirements

```bash
# Check versions
docker --version          # Docker 20.10+
minikube version         # Minikube 1.30+
kubectl version --client # kubectl 1.27+
helm version            # Helm 3.12+
```

### Automated Script

For a fully automated setup, you can use the provided script. This will start Minikube, enable the necessary addons, and open the Kubernetes dashboard and a tunnel for external access.

**To run the script:**

```bash
./scripts/setup_minikube.sh
```

This script performs the following actions:
- Starts Minikube with 4 CPUs and 8GB of memory.
- Enables `ingress`, `dns`, `metrics-server`, and `dashboard` addons.
- Opens the Kubernetes dashboard in your browser.
- Starts `minikube tunnel` to allow access to services of type `LoadBalancer`.

---
## Minikube Cluster Setup

### 1. Create Setup Script

Create `infrastructure/minikube/setup.sh`:

```bash
#!/bin/bash
set -euo pipefail

# Configuration
CLUSTER_NAME="k8s-rollouts"
K8S_VERSION="v1.28.3"
MEMORY="8192"
CPUS="4"
DISK_SIZE="20g"
DRIVER="docker"  # or "hyperkit" for macOS, "hyperv" for Windows

echo "🚀 Starting Minikube cluster setup..."

# Delete existing cluster if present
if minikube status -p ${CLUSTER_NAME} &>/dev/null; then
    echo "⚠️  Existing cluster found. Deleting..."
    minikube delete -p ${CLUSTER_NAME}
fi

# Start Minikube
echo "📦 Creating Minikube cluster..."
minikube start \
    --profile=${CLUSTER_NAME} \
    --driver=${DRIVER} \
    --kubernetes-version=${K8S_VERSION} \
    --memory=${MEMORY} \
    --cpus=${CPUS} \
    --disk-size=${DISK_SIZE} \
    --container-runtime=containerd \
    --addons=ingress,metrics-server,dashboard \
    --extra-config=kubelet.housekeeping-interval=10s

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=ready nodes --all --timeout=300s

# Enable additional addons
echo "🔧 Enabling additional addons..."
minikube addons enable ingress-dns -p ${CLUSTER_NAME}
minikube addons enable registry -p ${CLUSTER_NAME}
minikube addons enable storage-provisioner -p ${CLUSTER_NAME}

# Configure ingress
echo "🌐 Configuring NGINX Ingress..."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=300s

# Create namespaces
echo "📁 Creating namespaces..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace sample-app --dry-run=client -o yaml | kubectl apply -f -

# Label namespaces for monitoring
kubectl label namespace argocd monitoring=enabled --overwrite
kubectl label namespace sample-app monitoring=enabled --overwrite
kubectl label namespace default monitoring=enabled --overwrite

# Configure registry access
echo "🐳 Configuring local registry..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:5000"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# Display cluster info
echo "✅ Cluster setup complete!"
echo ""
echo "📊 Cluster Information:"
echo "========================"
kubectl cluster-info
echo ""
echo "🔗 Minikube IP: $(minikube ip -p ${CLUSTER_NAME})"
echo ""
echo "📝 Available Nodes:"
kubectl get nodes
echo ""
echo "🎯 Next Steps:"
echo "1. Run 'make deploy-argocd' to install ArgoCD"
echo "2. Configure /etc/hosts for ingress access"
echo "3. Access Kubernetes Dashboard: minikube dashboard -p ${CLUSTER_NAME}"
```

### 2. Configure Local DNS

Create `scripts/configure-dns.sh`:

```bash
#!/bin/bash
set -euo pipefail

MINIKUBE_IP=$(minikube ip -p k8s-rollouts)

echo "🔧 Configuring local DNS entries..."
echo "Minikube IP: ${MINIKUBE_IP}"

# Backup existing hosts file
sudo cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)

# Function to add/update host entry
add_host_entry() {
    local hostname=$1
    local ip=$2

    # Remove existing entry if present
    sudo sed -i.bak "/${hostname}/d" /etc/hosts

    # Add new entry
    echo "${ip} ${hostname}" | sudo tee -a /etc/hosts > /dev/null
    echo "✅ Added: ${ip} ${hostname}"
}

# Add entries for our services
add_host_entry "argocd.local" "${MINIKUBE_IP}"
add_host_entry "grafana.local" "${MINIKUBE_IP}"
add_host_entry "app.local" "${MINIKUBE_IP}"
add_host_entry "prometheus.local" "${MINIKUBE_IP}"
add_host_entry "rollouts.local" "${MINIKUBE_IP}"

echo ""
echo "✅ DNS configuration complete!"
echo ""
echo "You can now access:"
echo "  - ArgoCD UI: https://argocd.local"
echo "  - Grafana: http://grafana.local"
echo "  - Sample App: http://app.local"
echo "  - Prometheus: http://prometheus.local"
echo "  - Rollouts Dashboard: http://rollouts.local"
```

### 3. Resource Configuration

Create `infrastructure/minikube/resources.yaml`:

```yaml
# ResourceQuotas for namespaces
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: sample-app
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 4Gi
    limits.cpu: "8"
    limits.memory: 8Gi
    persistentvolumeclaims: "4"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: monitoring
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
---
# NetworkPolicies for security
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: sample-app
spec:
  podSelector: {}
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-ingress
  namespace: sample-app
spec:
  podSelector:
    matchLabels:
      app: sample-api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8000
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus-scraping
  namespace: sample-app
spec:
  podSelector:
    matchLabels:
      app: sample-api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
      ports:
        - protocol: TCP
          port: 8000
```

## NGINX Ingress Configuration

### 1. Custom NGINX Configuration

Create `infrastructure/minikube/nginx-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  # Enable Prometheus metrics
  enable-prometheus-metrics: "true"

  # Custom timeouts
  proxy-connect-timeout: "600"
  proxy-send-timeout: "600"
  proxy-read-timeout: "600"

  # Body size
  proxy-body-size: "10m"

  # Rate limiting
  limit-rate: "0"
  limit-rate-after: "0"

  # SSL/TLS
  ssl-protocols: "TLSv1.2 TLSv1.3"

  # Logging
  log-format-upstream:
    '{"time": "$time_iso8601", "remote_addr": "$proxy_protocol_addr",
    "x_forwarded_for": "$proxy_add_x_forwarded_for", "request_id": "$req_id",
    "remote_user": "$remote_user", "bytes_sent": $bytes_sent, "request_time": $request_time,
    "status": $status, "vhost": "$host", "request_proto": "$server_protocol",
    "path": "$uri", "request_query": "$args", "request_length": $request_length,
    "duration": $request_time, "method": "$request_method", "http_referrer": "$http_referer",
    "http_user_agent": "$http_user_agent", "upstream_addr": "$upstream_addr",
    "upstream_response_time": "$upstream_response_time", "upstream_status": "$upstream_status"}'
---
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx-controller-metrics
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/component: controller
spec:
  type: ClusterIP
  ports:
    - name: metrics
      port: 10254
      targetPort: 10254
      protocol: TCP
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/component: controller
```

### 2. Ingress Class Configuration

Create `infrastructure/minikube/ingress-class.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: k8s.io/ingress-nginx
```

## Storage Configuration

Create `infrastructure/minikube/storage.yaml`:

```yaml
# Default StorageClass with immediate binding
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: k8s.io/minikube-hostpath
parameters:
  type: pd-ssd
volumeBindingMode: Immediate
allowVolumeExpansion: true
---
# StorageClass for persistent data
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: persistent-data
provisioner: k8s.io/minikube-hostpath
parameters:
  type: pd-standard
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Retain
```

## Verification Steps

### 1. Cluster Health Check

Create `scripts/verify-cluster.sh`:

```bash
#!/bin/bash
set -euo pipefail

echo "🔍 Verifying Kubernetes cluster health..."
echo "========================================="
echo ""

# Function to check component
check_component() {
    local name=$1
    local namespace=$2
    local label=$3

    echo -n "Checking ${name}... "
    if kubectl get pods -n ${namespace} -l ${label} &>/dev/null; then
        local ready=$(kubectl get pods -n ${namespace} -l ${label} -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -o true | wc -l)
        local total=$(kubectl get pods -n ${namespace} -l ${label} --no-headers | wc -l)
        if [ "$ready" -eq "$total" ] && [ "$total" -gt 0 ]; then
            echo "✅ OK (${ready}/${total} pods ready)"
        else
            echo "⚠️  WARNING (${ready}/${total} pods ready)"
        fi
    else
        echo "❌ NOT FOUND"
    fi
}

# Check nodes
echo "📊 Cluster Nodes:"
kubectl get nodes -o wide
echo ""

# Check system pods
echo "🔧 System Components:"
check_component "CoreDNS" "kube-system" "k8s-app=kube-dns"
check_component "Ingress Controller" "ingress-nginx" "app.kubernetes.io/component=controller"
check_component "Metrics Server" "kube-system" "k8s-app=metrics-server"
echo ""

# Check namespaces
echo "📁 Namespaces:"
kubectl get namespaces
echo ""

# Check storage
echo "💾 Storage Classes:"
kubectl get storageclass
echo ""

# Check ingress
echo "🌐 Ingress Resources:"
kubectl get ingress -A
echo ""

# Display access information
echo "🔗 Access Information:"
echo "====================="
echo "Minikube IP: $(minikube ip -p k8s-rollouts)"
echo "Dashboard: Run 'minikube dashboard -p k8s-rollouts'"
echo ""
echo "✅ Verification complete!"
```

### 2. Troubleshooting Guide

Create `docs/troubleshooting.md`:

````markdown
# Troubleshooting Guide

## Common Issues and Solutions

### Minikube Won't Start

**Problem**: Minikube fails to start with driver errors.

**Solutions**:

1. Ensure Docker is running: `docker ps`
2. Clean up old instances: `minikube delete --all`
3. Try different driver: `--driver=virtualbox` or `--driver=hyperkit`
4. Increase resources: `--memory=16384 --cpus=8`

### Ingress Not Working

**Problem**: Cannot access services via ingress URLs.

**Solutions**:

1. Check ingress controller: `kubectl get pods -n ingress-nginx`
2. Verify DNS entries: `cat /etc/hosts`
3. Test with port-forward: `kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80`
4. Check ingress resources: `kubectl describe ingress -A`

### Out of Memory

**Problem**: Pods are being evicted due to memory pressure.

**Solutions**:

1. Increase Minikube memory: `minikube stop && minikube start --memory=16384`
2. Check resource usage: `kubectl top nodes && kubectl top pods -A`
3. Adjust resource limits in values files
4. Enable metrics-server: `minikube addons enable metrics-server`

### Image Pull Errors

**Problem**: Cannot pull images from local registry.

**Solutions**:

1. Build directly to Minikube: `minikube image build -t image:tag .`
2. Use Minikube registry: `minikube addons enable registry`
3. Load from Docker: `minikube image load image:tag`
4. Check registry config: `kubectl get cm -n kube-public local-registry-hosting`

### SSL/TLS Certificate Issues

**Problem**: Browser shows certificate warnings.

**Solutions**:

1. Accept self-signed certificates in browser
2. Add Minikube CA: `cat ~/.minikube/ca.crt >> /usr/local/share/ca-certificates/`
3. Use HTTP for local development
4. Configure proper certificates in production

## Debug Commands

```bash
# General cluster info
minikube status -p k8s-rollouts
kubectl cluster-info dump

# Pod debugging
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Network debugging
kubectl run debug --image=nicolaka/netshoot -it --rm
minikube ssh -p k8s-rollouts

# Resource usage
kubectl top nodes
kubectl top pods -A --sort-by=memory
```
````

```

## Summary

This infrastructure setup provides:

1. **Minikube Cluster**: Configured with sufficient resources and required addons
2. **NGINX Ingress**: Properly configured with metrics and custom settings
3. **Namespaces**: Organized with resource quotas and network policies
4. **Storage**: Multiple storage classes for different use cases
5. **DNS Configuration**: Local domain resolution for easy access
6. **Verification Tools**: Scripts to ensure everything is working correctly

Next steps:
- Deploy ArgoCD for GitOps workflow
- Set up the monitoring stack
- Deploy the sample application
```
