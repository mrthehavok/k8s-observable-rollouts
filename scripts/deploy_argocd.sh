#!/usr/bin/env bash
set -eo pipefail

# Create the Argo CD namespace if it doesn't exist
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Apply the core Argo CD installation manifests from the stable remote URL
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply the root application to bootstrap the App-of-Apps pattern
kubectl apply -f argocd-apps/root-app.yaml -n argocd

echo "Argo CD deployed ✔"

echo "⏳ Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

echo "🔑 Argo CD initial admin password:"
argocd admin initial-password -n argocd
echo "✅ Argo CD is ready."

echo ""
echo "🚀 You can now access the Argo CD UI by running:"
kubectl -n argocd port-forward svc/argocd-server 8080:443 &
echo "Then open your browser and go to http://localhost:8080"