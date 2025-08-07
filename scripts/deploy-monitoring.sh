#!/bin/bash
set -euo pipefail

MONITORING_VERSION="55.5.0"
NAMESPACE="monitoring"

echo "🚀 Deploying kube-prometheus-stack ${MONITORING_VERSION}..."

# Create namespace
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Add Prometheus community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
echo "📦 Installing kube-prometheus-stack..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace ${NAMESPACE} \
    --version ${MONITORING_VERSION} \
    --values infrastructure/monitoring/values.yaml \
    --wait \
    --timeout 10m

# Apply custom configurations
echo "🔧 Applying custom configurations..."
kubectl apply -f infrastructure/monitoring/config/

# Wait for components to be ready
echo "⏳ Waiting for monitoring components..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n ${NAMESPACE} --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n ${NAMESPACE} --timeout=300s

# Get Grafana admin password
echo "🔑 Retrieving Grafana admin password..."
GRAFANA_PASSWORD=$(kubectl get secret --namespace ${NAMESPACE} kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d)

echo ""
echo "✅ Monitoring stack deployment complete!"
echo ""
echo "📊 Access Information:"
echo "======================"
echo "Grafana URL: http://grafana.local"
echo "Username: admin"
echo "Password: ${GRAFANA_PASSWORD}"
echo ""
echo "Prometheus URL: http://prometheus.local"
echo "AlertManager URL: http://alertmanager.local"