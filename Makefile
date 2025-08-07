.PHONY: help cluster-up cluster-down deploy-infra deploy-app deploy-all test clean

CLUSTER_NAME := k8s-rollouts
MINIKUBE_MEMORY := 8192
MINIKUBE_CPUS := 4

help: ## Show this help
@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

cluster-up: ## Start Minikube cluster
@echo "Starting Minikube cluster..."
minikube start --driver=docker \
 --kubernetes-version=v1.28.3 \
 --memory=$(MINIKUBE_MEMORY) \
		--cpus=$(MINIKUBE_CPUS) \
 --profile=$(CLUSTER_NAME) \
 --addons=ingress,metrics-server
@echo "Cluster is ready!"

cluster-down: ## Stop and delete Minikube cluster
@echo "Stopping Minikube cluster..."
minikube delete --profile=$(CLUSTER_NAME)

deploy-argocd: ## Deploy ArgoCD
@echo "Deploying ArgoCD..."
./scripts/deploy-argocd.sh

deploy-monitoring: ## Deploy Prometheus and Grafana
@echo "Deploying monitoring stack..."
./scripts/deploy-monitoring.sh

deploy-app: ## Deploy sample application
@echo "Deploying sample application..."
kubectl apply -f infrastructure/argocd/applications/sample-app.yaml

deploy-all: deploy-argocd deploy-monitoring deploy-app ## Deploy entire stack

build-app: ## Build sample application Docker image
@echo "Building sample application..."
cd apps/sample-api && \
 minikube image build -t sample-api:latest .

test-unit: ## Run unit tests
@echo "Running unit tests..."
cd apps/sample-api && python -m pytest tests/

test-rollout: ## Test rollout strategies
@echo "Testing rollout strategies..."
./scripts/test-rollouts.sh

generate-traffic: ## Generate traffic to the application
@echo "Generating traffic..."
./scripts/generate-traffic.sh

promote-rollout: ## Promote current rollout
@echo "Promoting rollout..."
./scripts/promote-rollout.sh

rollback: ## Rollback to previous version
@echo "Rolling back..."
./scripts/rollback.sh

port-forward-argocd: ## Port forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

port-forward-grafana: ## Port forward Grafana UI
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80

clean: ## Clean up resources
kubectl delete -f infrastructure/argocd/applications/ || true
helm uninstall -n monitoring kube-prometheus-stack || true
helm uninstall -n argocd argocd || true

logs-app: ## Show application logs
kubectl logs -f -l app=sample-api -n default

status: ## Show cluster and application status
@echo "=== Cluster Status ==="
kubectl cluster-info
@echo "\n=== Nodes ==="
kubectl get nodes
@echo "\n=== ArgoCD Applications ==="
kubectl get applications -n argocd
@echo "\n=== Rollouts ==="
kubectl get rollouts -A
@echo "\n=== Pods ==="
kubectl get pods -A | grep -E "(argocd|sample-api|prometheus|grafana)"