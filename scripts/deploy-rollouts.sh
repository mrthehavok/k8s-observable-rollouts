#!/bin/bash
set -euo pipefail

ROLLOUTS_VERSION="v1.6.4"
NAMESPACE="argo-rollouts"

echo "🚀 Deploying Argo Rollouts ${ROLLOUTS_VERSION}..."

# Create namespace
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Install Argo Rollouts via Helm
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argo-rollouts argo/argo-rollouts \
    --namespace ${NAMESPACE} \
    --set controller.metrics.enabled=true \
    --set controller.metrics.serviceMonitor.enabled=true \
    --set dashboard.enabled=true \
    --set dashboard.ingress.enabled=true \
    --set dashboard.ingress.hosts[0]=rollouts.local \
    --set dashboard.ingress.ingressClassName=nginx \
    --wait

# Install kubectl plugin
echo "💻 Installing kubectl-argo-rollouts plugin..."
curl -LO https://github.com/argoproj/argo-rollouts/releases/download/${ROLLOUTS_VERSION}/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

echo "✅ Argo Rollouts deployment complete!"
echo "Dashboard available at: http://rollouts.local"