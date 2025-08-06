#!/usr/bin/env bash
set -eo pipefail

# Apply the Argo CD namespace first
kubectl apply -f argocd/namespace.yaml

# Apply the core Argo CD installation manifests
kubectl apply -f argocd/install.yaml -n argocd

# Apply the root application to bootstrap the App-of-Apps pattern
kubectl apply -f argocd-apps/root-app.yaml -n argocd

echo "Argo CD deployed ✔"

echo "⏳ Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

echo "⏳ Waiting for initial admin secret to be created..."
kubectl wait --for=condition=exists secret/argocd-initial-admin-secret -n argocd --timeout=120s

echo "🔑 Argo CD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
echo ""
echo "🚀 You can now access the Argo CD UI by running:"
echo "kubectl -n argocd port-forward svc/argocd-server 8080:443"