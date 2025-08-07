#!/bin/bash
set -euo pipefail

MINIKUBE_IP=$(minikube ip -p k8s-rollouts)

echo "🔧 Configuring local DNS entries..."
echo "Minikube IP: ${MINIKUBE_IP}"

# Backup existing hosts file
sudo cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)

# Function to add/update host entry
add_host_entry() {
    local hostname=$1
    local ip=$2

    # Remove existing entry if present
    sudo sed -i.bak "/${hostname}/d" /etc/hosts

    # Add new entry
    echo "${ip} ${hostname}" | sudo tee -a /etc/hosts > /dev/null
    echo "✅ Added: ${ip} ${hostname}"
}

# Add entries for our services
add_host_entry "argocd.local" "${MINIKUBE_IP}"
add_host_entry "grafana.local" "${MINIKUBE_IP}"
add_host_entry "app.local" "${MINIKUBE_IP}"
add_host_entry "prometheus.local" "${MINIKUBE_IP}"
add_host_entry "rollouts.local" "${MINIKUBE_IP}"

echo ""
echo "✅ DNS configuration complete!"
echo ""
echo "You can now access:"
echo "  - ArgoCD UI: https://argocd.local"
echo "  - Grafana: http://grafana.local"
echo "  - Sample App: http://app.local"
echo "  - Prometheus: http://prometheus.local"
echo "  - Rollouts Dashboard: http://rollouts.local"
