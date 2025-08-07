#!/bin/bash
set -euo pipefail

echo "🔍 Verifying Kubernetes cluster health..."
echo "========================================="
echo ""

# Function to check component
check_component() {
    local name=$1
    local namespace=$2
    local label=$3

    echo -n "Checking ${name}... "
    if kubectl get pods -n ${namespace} -l ${label} &>/dev/null; then
        local ready=$(kubectl get pods -n ${namespace} -l ${label} -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -o true | wc -l)
        local total=$(kubectl get pods -n ${namespace} -l ${label} --no-headers | wc -l)
        if [ "$ready" -eq "$total" ] && [ "$total" -gt 0 ]; then
            echo "✅ OK (${ready}/${total} pods ready)"
        else
            echo "⚠️  WARNING (${ready}/${total} pods ready)"
        fi
    else
        echo "❌ NOT FOUND"
    fi
}

# Check nodes
echo "📊 Cluster Nodes:"
kubectl get nodes -o wide
echo ""

# Check system pods
echo "🔧 System Components:"
check_component "CoreDNS" "kube-system" "k8s-app=kube-dns"
check_component "Ingress Controller" "ingress-nginx" "app.kubernetes.io/component=controller"
check_component "Metrics Server" "kube-system" "k8s-app=metrics-server"
echo ""

# Check namespaces
echo "📁 Namespaces:"
kubectl get namespaces
echo ""

# Check storage
echo "💾 Storage Classes:"
kubectl get storageclass
echo ""

# Check ingress
echo "🌐 Ingress Resources:"
kubectl get ingress -A
echo ""

# Display access information
echo "🔗 Access Information:"
echo "====================="
echo "Minikube IP: $(minikube ip -p k8s-rollouts)"
echo "Dashboard: Run 'minikube dashboard -p k8s-rollouts'"
echo ""
echo "✅ Verification complete!"