# Kubernetes Observable Rollouts on Minikube

End-to-end local environment for GitOps and progressive delivery:

- Minikube
- Argo CD (App-of-Apps)
- Argo Rollouts
- Sample FastAPI service
- kube-prometheus-stack (Prometheus + Grafana)

All steps prefer project scripts and manifests with precise file links.

## Table of Contents

- 1. Prerequisites
- 2. Quickstart (TL;DR)
- 3. Step-by-step Setup
- 4. Validation Checklist
- 5. Progressive Delivery (Optional Smoke Test)
- 6. Troubleshooting
- 7. Cleanup

## 1. Prerequisites

- OS: Linux/macOS (Windows via WSL2)
- Tools:
  - kubectl (≥ 1.27)
  - helm (≥ 3.12)
  - minikube (≥ 1.30)
  - docker or podman
  - Optional: argocd CLI
- Resources: ≥ 4 CPU, ≥ 8 GB RAM

Reference: [docs/infrastructure-setup.md](docs/infrastructure-setup.md)

## 2. Quickstart (TL;DR)

```bash
# Clone
git clone https://github.com/mrthehavok/k8s-observable-rollouts.git
cd k8s-observable-rollouts

# Start cluster (+ addons, dashboard, tunnel, namespaces)
bash scripts/setup_minikube.sh

# Install Argo CD (Helm) + configure + apply App-of-Apps
bash scripts/setup_argocd.sh

# Verify Argo CD install, applications, and sync/health
bash scripts/verify_argocd.sh

# Apply (or re-apply) root App-of-Apps if needed
kubectl -n argocd apply -f infrastructure/argocd/applications/app-of-apps.yaml

# Optional helpers (runs tunnel and port-forward for ArgoCD in background)
bash scripts/minikube_dev.sh start
```

Notes:

- [scripts/setup_minikube.sh](scripts/setup_minikube.sh) already starts the dashboard and `minikube tunnel` in the background.
- [scripts/setup_argocd.sh](scripts/setup_argocd.sh) already applies the root App-of-Apps.

## 3. Step-by-step Setup

### 3.1 Clone the repository

```bash
git clone https://github.com/mrthehavok/k8s-observable-rollouts.git
cd k8s-observable-rollouts
```

### 3.2 Start Minikube

Run the helper script:

- Starts cluster with Kubernetes v1.33.1, 4 CPU, 8GB RAM, 20Gi disk
- Enables ingress, metrics-server, dashboard
- Waits for readiness
- Enables registry, storage-provisioner
- Waits for NGINX Ingress controller
- Creates namespaces: argocd, monitoring, sample-app
- Labels namespaces for monitoring
- Starts Kubernetes Dashboard (background)
- Starts `minikube tunnel` (background)

Command:

```bash
bash scripts/setup_minikube.sh
```

Script reference: [scripts/setup_minikube.sh](scripts/setup_minikube.sh)

### 3.3 Optional dev helpers

The dev control script:

- start: Minikube + dashboard (bg) + tunnel (bg) + ArgoCD port-forward (bg)
- status: cluster/services and helper PIDs
- stop: stop helpers and Minikube

```bash
# Start helpers (if not already running)
bash scripts/minikube_dev.sh start

# Status
bash scripts/minikube_dev.sh status

# Stop helpers + Minikube
bash scripts/minikube_dev.sh stop
```

Reference: [scripts/minikube_dev.sh](scripts/minikube_dev.sh)

### 3.4 Registry / image strategy

Default image: `ghcr.io/mrthehavok/sample-api:latest` from [charts/sample-api/values.yaml](charts/sample-api/values.yaml)

Local build options:

- Build into Minikube’s container runtime:
  ```bash
  minikube image build -t ghcr.io/mrthehavok/sample-api:dev apps/sample-api
  ```
  Then set `.Values.image.tag=dev` in [charts/sample-api/values.yaml](charts/sample-api/values.yaml)
- Or load an existing image:
  ```bash
  docker build -t ghcr.io/mrthehavok/sample-api:dev apps/sample-api
  minikube image load ghcr.io/mrthehavok/sample-api:dev
  ```

Dockerfile: [apps/sample-api/Dockerfile](apps/sample-api/Dockerfile)

### 3.5 Install and access Argo CD

Install via Helm + project values, apply configs, auto-login via port-forward, and apply App-of-Apps:

```bash
bash scripts/setup_argocd.sh
```

What it does:

- Namespace: `argocd`
- Install method: Helm (chart version 8.2.2)
- Values file: [infrastructure/argocd/values.yaml](infrastructure/argocd/values.yaml)
- Applies custom configs: [infrastructure/argocd/config/](infrastructure/argocd/config/)
- Retrieves initial admin password from the Secret
- Installs argocd CLI (if missing) and logs in via 127.0.0.1:8080 (port-forward)
- Applies App-of-Apps: [infrastructure/argocd/applications/app-of-apps.yaml](infrastructure/argocd/applications/app-of-apps.yaml)

Manual Argo CD UI port-forward:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
# URL: https://localhost:8080
```

Default login:

- Username: admin
- Password: read from secret or as documented in [docs/deployment-guide.md](docs/deployment-guide.md)

### 3.6 Deploy App-of-Apps and dependent apps

Root App-of-Apps:

- Namespace: `argocd`
- Auto-sync: enabled (prune + selfHeal)

Apply or re-apply:

```bash
kubectl -n argocd apply -f infrastructure/argocd/applications/app-of-apps.yaml
```

Files:

- Root: [infrastructure/argocd/applications/app-of-apps.yaml](infrastructure/argocd/applications/app-of-apps.yaml)
- Rollouts: [infrastructure/argocd/applications/argo-rollouts.yaml](infrastructure/argocd/applications/argo-rollouts.yaml)
- Monitoring: [infrastructure/argocd/applications/monitoring.yaml](infrastructure/argocd/applications/monitoring.yaml)
- Sample app: [infrastructure/argocd/applications/sample-app.yaml](infrastructure/argocd/applications/sample-app.yaml)

Argo CD will sync automatically; you can also sync from the UI.

### 3.7 Expose services

Ingress (default):

- Sample API ingress host: `sample-api.local`
- Ingress config: [charts/sample-api/values.yaml](charts/sample-api/values.yaml), [charts/sample-api/templates/ingress.yaml](charts/sample-api/templates/ingress.yaml)
- Ensure your system resolves `sample-api.local` to the Minikube IP (e.g., add to `/etc/hosts`), or use port-forward below.

Alternative (port-forward the stable service):

```bash
kubectl -n sample-app port-forward \
  svc/$(kubectl -n sample-app get svc -l app.kubernetes.io/name=sample-api -o jsonpath='{.items[0].metadata.name}') \
  8080:8000
# Now use http://127.0.0.1:8080
```

## 4. Validation Checklist

Argo CD installation and apps:

- Command:
  ```bash
  bash scripts/verify_argocd.sh
  ```
  Reference: [scripts/verify_argocd.sh](scripts/verify_argocd.sh)

Argo Rollouts controller and CRDs:

```bash
kubectl get crd | grep rollouts.argoproj.io
kubectl -n argo-rollouts get deploy,pods
```

Manifest: [infrastructure/argocd/applications/argo-rollouts.yaml](infrastructure/argocd/applications/argo-rollouts.yaml)

Sample API endpoints (choose one approach):

- Ingress:
  ```bash
  # After mapping sample-api.local to Minikube IP
  curl -sSf http://sample-api.local/health/ready
  curl -sSf http://sample-api.local/health/live
  curl -sSf http://sample-api.local/api/info
  curl -sSf http://sample-api.local/metrics
  ```
- Port-forward:
  ```bash
  # from 3.7 alternative
  curl -sSf http://127.0.0.1:8080/health/ready
  curl -sSf http://127.0.0.1:8080/health/live
  curl -sSf http://127.0.0.1:8080/api/info
  curl -sSf http://127.0.0.1:8080/metrics
  ```
  Handlers:
- Health: [apps/sample-api/app/routes/health.py](apps/sample-api/app/routes/health.py)
- Info: [apps/sample-api/app/routes/info.py](apps/sample-api/app/routes/info.py)
- Metrics: [apps/sample-api/app/metrics.py](apps/sample-api/app/metrics.py)

Observability (port-forward UIs):

```bash
# Prometheus
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090

# Grafana
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Datasources/dashboards templates:

- [infrastructure/monitoring/templates/grafana-datasources.yaml](infrastructure/monitoring/templates/grafana-datasources.yaml)
- [infrastructure/monitoring/templates/grafana-dashboards.yaml](infrastructure/monitoring/templates/grafana-dashboards.yaml)

## 5. Progressive Delivery (Optional Smoke Test)

GitOps-first approach:

- Update image tag in values and let Argo CD sync.

Edit:

- [charts/sample-api/values.yaml](charts/sample-api/values.yaml)
  - `.image.repository: ghcr.io/mrthehavok/sample-api`
  - `.image.tag: "vX.Y.Z"`

Commit and push to the repo referenced by the Application:

- App source: [infrastructure/argocd/applications/sample-app.yaml](infrastructure/argocd/applications/sample-app.yaml)

Argo CD will sync automatically (auto-sync enabled). Otherwise, sync via Argo CD UI.

Alternative demo (direct patch; Argo CD may revert drift depending on policy):

```bash
# Patch the Rollout image directly (non-GitOps demo)
kubectl -n sample-app set image rollout/sample-api \
  sample-api=ghcr.io/mrthehavok/sample-api:vX.Y.Z
```

References:

- Rollout template: [charts/sample-api/templates/rollout.yaml](charts/sample-api/templates/rollout.yaml)
- Strategies: [docs/rollout-strategies.md](docs/rollout-strategies.md)

## 6. Troubleshooting

Common references:

- Deployment guide: [docs/deployment-guide.md](docs/deployment-guide.md)
- Infrastructure setup: [docs/infrastructure-setup.md](docs/infrastructure-setup.md)
- Integration testing: [docs/integration-testing.md](docs/integration-testing.md)
- Observability stack: [docs/observability-stack.md](docs/observability-stack.md)

Quick checks:

```bash
# Cluster status
kubectl cluster-info
kubectl get pods -A

# Argo CD apps
kubectl -n argocd get applications

# Rollouts
kubectl -n sample-app get rollouts

# Ingress
kubectl -n sample-app describe ingress
```

## 7. Cleanup

- Remove applications via Argo CD UI or delete root Application:
  ```bash
  kubectl -n argocd delete application app-of-apps
  ```
- Stop helpers and Minikube:
  ```bash
  bash scripts/minikube_dev.sh stop
  minikube delete
  ```
  Helpers reference: [scripts/minikube_dev.sh](scripts/minikube_dev.sh)

My commands
./scripts/setup_minikube.sh
./scripts/setup_argocd.sh
kubectl -n argocd port-forward svc/argocd-server 8080:443
kubectl -n argocd apply -f infrastructure/argocd/applications/app-of-apps.yaml
kubectl -n argocd apply -f infrastructure/argocd/applications/argo-rollouts.yaml
helm repo update
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl apply -k https://github.com/argoproj/argo-rollouts/manifests/crds\?ref\=stable
kubectl -n argo-rollouts delete deployment argo-rollouts
