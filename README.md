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
   ```

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
