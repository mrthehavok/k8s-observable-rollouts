#!/bin/bash
set -euo pipefail

echo "🔍 Verifying ArgoCD installation..."
echo "===================================="
echo ""

# Check ArgoCD pods
echo "📦 ArgoCD Pods:"
kubectl get pods -n argocd
echo ""

# Check applications
echo "📱 ArgoCD Applications:"
kubectl get applications -n argocd
echo ""

# Check sync status
echo "🔄 Application Sync Status:"
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision
echo ""

# Check ingress
echo "🌐 ArgoCD Ingress:"
kubectl get ingress -n argocd
echo ""

echo "✅ Verification complete!"