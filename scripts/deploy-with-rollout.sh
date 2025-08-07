#!/bin/bash
set -euo pipefail

NAMESPACE="sample-app"
APP_NAME="sample-api"
NEW_VERSION="${1:-}"

if [ -z "$NEW_VERSION" ]; then
    echo "Usage: $0 <new-version>"
    exit 1
fi

echo "🚀 Starting deployment of ${APP_NAME} version ${NEW_VERSION}"

# Update image tag
echo "📝 Updating Helm values..."
helm upgrade ${APP_NAME} ./charts/${APP_NAME} \
    --namespace ${NAMESPACE} \
    --reuse-values \
    --set image.tag=${NEW_VERSION}

# Monitor rollout
echo "📊 Monitoring rollout progress..."
kubectl argo rollouts get rollout ${APP_NAME} -n ${NAMESPACE} --watch