# Project Structure and Initialization Guide

## Directory Structure Overview

This document provides a detailed guide for setting up the k8s-observable-rollouts monorepo structure.

## Creating the Project Structure

Run these commands to create the full directory structure:

````bash
# Create root directories
mkdir -p docs infrastructure/{minikube,argocd/applications,monitoring/{dashboards,alerts}}
mkdir -p apps/sample-api/{app/{routes,templates},tests}
mkdir -p charts/sample-api/{templates,rollout-strategies}
mkdir -p scripts

# Create .gitignore
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
.env
.venv
*.egg-info/
dist/
build/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Kubernetes
*.kubeconfig
kubeconfig

# Helm
charts/*/charts/
charts/*/Chart.lock

# Terraform (if used later)
*.tfstate
*.tfstate.*
.terraform/

# Logs
*.log

# Temporary files
*.tmp
*.temp
EOF

# Create README.md
cat > README.md << 'EOF'
# K8s Observable Rollouts

A comprehensive GitOps demonstration project showcasing progressive delivery strategies with full observability on Kubernetes.

## 🎯 Project Goals

- Implement GitOps workflow using ArgoCD
- Demonstrate blue/green and canary deployments with Argo Rollouts
- Provide comprehensive observability with Prometheus and Grafana
- Create a reproducible local development environment with Minikube

## 📋 Prerequisites

- Docker Desktop or Docker Engine
- Minikube v1.30+
- kubectl v1.27+
- Helm v3.12+
- Python 3.11+ (for local development)
- Make (optional, for automation)

## 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd k8s-observable-rollouts
````

2. **Set up the local cluster**

   ```bash
   make cluster-up
   ```

3. **Deploy the stack**

   ```bash
   make deploy-all
   ```

4. **Access the services**
   - ArgoCD UI: https://argocd.local
   - Grafana: https://grafana.local
   - Sample App: https://app.local

## 📁 Repository Structure

```
.
├── apps/               # Application source code
├── charts/             # Helm charts
├── docs/               # Documentation
├── infrastructure/     # Infrastructure configurations
└── scripts/            # Utility scripts
```

## 📖 Documentation

- [Architecture Design](docs/architecture-design.md)
- [Project Structure](docs/project-structure.md)
- [Deployment Guide](docs/deployment-guide.md)
- [Rollout Strategies](docs/rollout-strategies.md)

## 🛠️ Technology Stack

- **Container Orchestration**: Kubernetes (Minikube)
- **GitOps**: ArgoCD
- **Progressive Delivery**: Argo Rollouts
- **Package Management**: Helm
- **Monitoring**: Prometheus & Grafana
- **Application**: Python FastAPI
- **Ingress**: NGINX

## 📊 Features

- ✅ GitOps-driven deployments
- ✅ Blue/Green deployment strategy
- ✅ Canary deployment with traffic splitting
- ✅ Automated rollback on failures
- ✅ Real-time metrics and dashboards
- ✅ Custom application metrics
- ✅ Version tracking and display

## 🤝 Contributing

Please read our contributing guidelines before submitting PRs.

## 📄 License

This project is licensed under the MIT License.
EOF

# Create Makefile

cat > Makefile << 'EOF'
.PHONY: help cluster-up cluster-down deploy-infra deploy-app deploy-all test clean

CLUSTER_NAME := k8s-rollouts
MINIKUBE_MEMORY := 8192
MINIKUBE_CPUS := 4

help: ## Show this help
@grep -E '^[a-zA-Z_-]+:._?## ._$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.\*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

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
EOF

```

## File Templates

### Python Application Structure

**apps/sample-api/requirements.txt**:
```

fastapi==0.104.1
uvicorn[standard]==0.24.0
prometheus-client==0.19.0
pydantic==2.5.0
pydantic-settings==2.1.0
jinja2==3.1.2
httpx==0.25.2

````

**apps/sample-api/Dockerfile**:
```dockerfile
# Multi-stage build for optimal size
FROM python:3.11-slim as builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.11-slim

WORKDIR /app

# Copy Python dependencies from builder
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

# Copy application code
COPY ./app ./app

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import httpx; httpx.get('http://localhost:8000/health/ready').raise_for_status()"

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
````

### Helm Chart Structure

**charts/sample-api/Chart.yaml**:

```yaml
apiVersion: v2
name: sample-api
description: A FastAPI sample application with progressive delivery
type: application
version: 0.1.0
appVersion: "1.0.0"
keywords:
  - fastapi
  - argo-rollouts
  - gitops
maintainers:
  - name: Your Name
    email: your.email@example.com
dependencies:
  - name: argo-rollouts
    version: "2.32.0"
    repository: https://argoproj.github.io/argo-helm
    condition: rollouts.enabled
```

**charts/sample-api/values.yaml**:

```yaml
# Default values for sample-api
replicaCount: 2

image:
  repository: sample-api
  pullPolicy: IfNotPresent
  tag: "latest"

service:
  type: ClusterIP
  port: 80
  targetPort: 8000

ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
  hosts:
    - host: app.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

# Rollout configuration
rollout:
  enabled: true
  strategy: blueGreen # or canary

# Blue/Green specific
blueGreen:
  autoPromotionEnabled: false
  scaleDownDelaySeconds: 30
  prePromotionAnalysis:
    enabled: true

# Canary specific
canary:
  steps:
    - setWeight: 20
    - pause: { duration: 2m }
    - setWeight: 50
    - pause: { duration: 2m }
    - setWeight: 100
  analysis:
    enabled: true
    successRate: 95
    latencyP99: 500

# Prometheus metrics
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
    path: /metrics

# Application configuration
app:
  config:
    environment: "development"
    logLevel: "INFO"
    version: "1.0.0"
```

### Infrastructure Configuration

**infrastructure/argocd/values.yaml**:

```yaml
# ArgoCD Helm chart values
server:
  extraArgs:
    - --insecure
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - argocd.local
    paths:
      - /
    pathType: Prefix

controller:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true

repoServer:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true

# Enable Argo Rollouts UI
configs:
  params:
    server.disable.auth: true
    application.instanceLabelKey: argocd.argoproj.io/instance
```

**infrastructure/monitoring/values.yaml**:

```yaml
# kube-prometheus-stack values
grafana:
  enabled: true
  adminPassword: admin
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - grafana.local
  sidecar:
    dashboards:
      enabled: true
      searchNamespace: ALL
      provider:
        foldersFromFilesStructure: true

prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorSelector: {}
    serviceMonitorNamespaceSelector: {}
    retention: 7d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

alertmanager:
  enabled: true
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 2Gi
```

## Next Steps

1. Create the directory structure using the commands above
2. Initialize git repository: `git init`
3. Create initial commit: `git add . && git commit -m "Initial project structure"`
4. Proceed with implementing the FastAPI application
5. Set up the Helm charts
6. Configure ArgoCD applications
7. Implement rollout strategies
