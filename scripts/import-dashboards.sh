#!/bin/bash
set -euo pipefail

GRAFANA_URL="http://grafana.local"
GRAFANA_USER="admin"
GRAFANA_PASS=$(kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d)
DASHBOARD_DIR="./infrastructure/monitoring/dashboards"

echo "📊 Importing Grafana dashboards..."

for dashboard in ${DASHBOARD_DIR}/*.json; do
    echo "Importing $(basename ${dashboard})..."

    curl -X POST \
        -H "Content-Type: application/json" \
        -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
        -d @${dashboard} \
        ${GRAFANA_URL}/api/dashboards/db
done

echo "✅ Dashboard import completed"