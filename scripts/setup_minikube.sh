#!/usr/bin/env bash
set -eo pipefail

# Start Minikube with required resources and addons
echo "🚀 Starting Minikube..."
minikube start --cpus 4 --memory 8192 --driver=docker \
  --addons ingress,dns,metrics-server,dashboard

# Verify cluster nodes
echo "✅ Verifying cluster nodes..."
kubectl get nodes -o wide

echo "🎉 Minikube cluster is ready."

# Open dashboard in the background
echo "🔌 Opening Kubernetes Dashboard in the background..."
minikube dashboard &

# Start tunnel in the background.
# This is required to expose services of type LoadBalancer.
echo "🚇 Starting Minikube tunnel in the background..."
minikube tunnel &

echo "✅ Script finished. Dashboard and tunnel are running in the background."
echo "You can find the dashboard URL in the output above."
echo "To stop the background processes, you can close this terminal."