#!/bin/bash
set -euo pipefail

VERSION=${1:-}
ENVIRONMENT=${2:-staging}
APP_NAME="sample-api"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> [environment]"
    exit 1
fi

echo "🚀 Deploying ${APP_NAME} ${VERSION} to ${ENVIRONMENT}"

# Update values file
case $ENVIRONMENT in
    dev)
        VALUES_FILE="values-dev.yaml"
        NAMESPACE="sample-app-dev"
        ;;
    staging)
        VALUES_FILE="values-staging.yaml"
        NAMESPACE="sample-app-staging"
        ;;
    prod)
        VALUES_FILE="values-prod.yaml"
        NAMESPACE="sample-app"
        ;;
    *)
        echo "Unknown environment: $ENVIRONMENT"
        exit 1
        ;;
esac

# Update image tag
yq eval ".image.tag = \"${VERSION}\"" -i charts/${APP_NAME}/${VALUES_FILE}

# Commit and push
git add charts/${APP_NAME}/${VALUES_FILE}
git commit -m "deploy: ${APP_NAME} ${VERSION} to ${ENVIRONMENT}"
git push origin main

# Wait for ArgoCD sync
echo "⏳ Waiting for ArgoCD sync..."
argocd app wait ${APP_NAME}-${ENVIRONMENT} --sync

# Monitor rollout
echo "📊 Monitoring rollout..."
kubectl argo rollouts get rollout ${APP_NAME} -n ${NAMESPACE} --watch