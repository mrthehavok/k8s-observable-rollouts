#!/usr/bin/env bash
set -eo pipefail

ARGOCD_VERSION="8.2.2"
ARGOCD_NAMESPACE="argocd"

echo "🚀 Deploying ArgoCD ${ARGOCD_VERSION}..."

# Create namespace
kubectl create namespace ${ARGOCD_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
echo "📦 Installing ArgoCD via Helm..."
helm upgrade --install argocd argo/argo-cd \
    --namespace ${ARGOCD_NAMESPACE} \
    --version ${ARGOCD_VERSION} \
    --values infrastructure/argocd/values.yaml \
    --wait

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD components..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n ${ARGOCD_NAMESPACE} --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n ${ARGOCD_NAMESPACE} --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n ${ARGOCD_NAMESPACE} --timeout=300s

# Apply custom configurations
echo "🔧 Applying custom configurations..."
kubectl apply -f infrastructure/argocd/config/


# Get initial admin password
echo "🔑 Retrieving admin password..."
ARGOCD_PASSWORD=$(kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Install ArgoCD CLI
echo "💻 Installing ArgoCD CLI..."
if ! command -v argocd &> /dev/null; then
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo chmod +x /tmp/argocd
    sudo mv /tmp/argocd /usr/local/bin/argocd
fi

# Configure ArgoCD CLI
echo "🔧 Configuring ArgoCD CLI..."
argocd login argocd.local --username admin --password "${ARGOCD_PASSWORD}" --insecure

# Deploy App of Apps
echo "🎯 Deploying App of Apps..."
kubectl apply -f infrastructure/argocd/applications/app-of-apps.yaml
echo "Argo CD deployed ✔"

echo "⏳ Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

#echo "🔑 Argo CD initial admin password:"
#argocd admin initial-password -n argocd
#echo "✅ Argo CD is ready."

echo ""
echo "🚀 You can now access the Argo CD UI"
kubectl -n argocd port-forward svc/argocd-server 8080:443