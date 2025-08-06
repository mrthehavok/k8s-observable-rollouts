#!/usr/bin/env bash
set -eo pipefail

# Apply the Argo CD namespace first
kubectl apply -f argocd/namespace.yaml

# Apply the core Argo CD installation manifests
kubectl apply -f argocd/install.yaml

# Apply the root application to bootstrap the App-of-Apps pattern
kubectl apply -f argocd-apps/root-app.yaml

echo "Argo CD deployed ✔"