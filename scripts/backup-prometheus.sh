#!/bin/bash
set -euo pipefail

NAMESPACE="monitoring"
PROMETHEUS_POD=$(kubectl get pod -n ${NAMESPACE} -l app.kubernetes.io/name=prometheus -o jsonpath="{.items[0].metadata.name}")
BACKUP_DIR="./backups/prometheus/$(date +%Y%m%d_%H%M%S)"

echo "📦 Creating Prometheus backup..."
mkdir -p ${BACKUP_DIR}

# Create snapshot
echo "Creating snapshot..."
kubectl exec -n ${NAMESPACE} ${PROMETHEUS_POD} -c prometheus -- \
    curl -XPOST http://localhost:9090/api/v1/admin/tsdb/snapshot

# Get snapshot name
SNAPSHOT=$(kubectl exec -n ${NAMESPACE} ${PROMETHEUS_POD} -c prometheus -- \
    ls -t /prometheus/snapshots | head -1)

# Copy snapshot
echo "Copying snapshot ${SNAPSHOT}..."
kubectl cp ${NAMESPACE}/${PROMETHEUS_POD}:/prometheus/snapshots/${SNAPSHOT} \
    ${BACKUP_DIR}/${SNAPSHOT} -c prometheus

echo "✅ Backup completed: ${BACKUP_DIR}/${SNAPSHOT}"