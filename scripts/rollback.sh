#!/bin/bash
set -euo pipefail

NAMESPACE="sample-app"
APP_NAME="sample-api"

echo "⚠️  Starting rollback of ${APP_NAME}"

# Abort current rollout
kubectl argo rollouts abort ${APP_NAME} -n ${NAMESPACE}

# Undo to previous version
kubectl argo rollouts undo ${APP_NAME} -n ${NAMESPACE}

# Or rollback to specific revision
# kubectl argo rollouts undo ${APP_NAME} -n ${NAMESPACE} --to-revision=3

echo "✅ Rollback completed"