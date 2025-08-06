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

echo "⏳ Waiting for initial admin secret to be created..."
kubectl wait --for=condition=exists secret/argocd-initial-admin-secret -n argocd --timeout=120s

echo "🔑 Retrieving initial admin password and storing it in a new secret..."

# Get the decoded password
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Create a new, non-expiring secret with the password
kubectl -n argocd create secret generic argocd-admin-password \
  --from-literal=password="$ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Admin password stored in secret 'argocd-admin-password'."
echo ""
echo "🚀 You can now access the Argo CD UI by running:"
echo "kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo ""
echo "💡 Login with username 'admin' and the password from the 'argocd-admin-password' secret."