#!/usr/bin/env bash
set -eo pipefail

K8S_VERSION="v1.33.1"
MEMORY="8192"
CPUS="4"
DISK_SIZE="20g"
DRIVER="docker"  # or "hyperkit" for macOS, "hyperv" for Windows

# Delete existing cluster if present
if minikube status -p ${CLUSTER_NAME} &>/dev/null; then
    echo "⚠️  Existing cluster found. Deleting..."
    minikube delete -p ${CLUSTER_NAME}
fi

# Start Minikube
echo "📦 Creating Minikube cluster..."
minikube start \
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
minikube addons enable registry 
minikube addons enable storage-provisioner 

# Configure ingress
echo "🌐 Configuring NGINX Ingress..."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=300s

echo "🎉 Minikube cluster is ready."

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
echo "🔗 Minikube IP: $(minikube ip )"
echo ""
echo "📝 Available Nodes:"
kubectl get nodes

# Open dashboard in the background
echo "🔌 Opening Kubernetes Dashboard in the background..."
minikube dashboard &

# Start tunnel in the background.
# This is required to expose services of type LoadBalancer.
echo "🚇 Starting Minikube tunnel in the background..."
minikube tunnel &

echo "✅ Script finished. Dashboard and tunnel are running in the background."
echo "You can find the dashboard URL in the output above."
echo "To stop the background processes, you can close this terminal."