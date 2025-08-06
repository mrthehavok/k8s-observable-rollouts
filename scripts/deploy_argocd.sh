#!/usr/bin/env bash
set -eo pipefail

# This script bootstraps the Argo CD installation by applying the root Application resource.
# The root Application will then deploy Argo CD itself, following the App-of-Apps pattern.

echo "Applying Argo CD root application..."
kubectl apply -f argocd-apps/root-app.yaml

echo "Argo CD deployment initiated. It may take a few minutes for all components to become healthy."
echo "To access the Argo CD UI, run the following command in a separate terminal:"
echo "kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo ""
echo "You can get the initial admin password with:"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d; echo"