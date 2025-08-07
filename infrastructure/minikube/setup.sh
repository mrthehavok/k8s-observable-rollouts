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