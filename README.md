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
- 8. Release Management and Versioning

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

## My commands

Quick reference used during bring-up and recovery. Commands are grouped and annotated to be copy-paste friendly.

1. Bootstrap cluster

```bash
# Start Minikube and core addons; creates namespaces; runs dashboard + tunnel in background
bash scripts/setup_minikube.sh
```

2. Install Argo CD and apply App-of-Apps

```bash
# Helm install Argo CD + configure + apply root app
bash scripts/setup_argocd.sh
```

Manual Argo CD UI port-forward (if needed):

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
# URL: https://localhost:8080
```

3. Re-apply root App-of-Apps if needed

```bash
kubectl -n argocd apply -f infrastructure/argocd/applications/app-of-apps.yaml
```

4. Argo Rollouts recovery — GitOps preferred

```bash
# Pre-seed CRDs to avoid Helm/Argo patch conflicts
kubectl apply -f https://github.com/argoproj/argo-rollouts/releases/latest/download/crds.yaml

# If a conflicting controller deployment exists, remove it so Argo CD can recreate
kubectl -n argo-rollouts delete deployment argo-rollouts --ignore-not-found

# Ensure pinned Helm version is set in the Argo CD Application, then sync in UI
# Optional via CLI:
# argocd app sync argo-rollouts --prune --replace
```

Fallback — direct install (not recommended long-term):

```bash
helm repo update
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

5. Access the sample API

```bash
# Prefer Ingress via sample-api.local after mapping to Minikube IP
# Or use port-forward; note 8080 may be used by Argo CD, so use 8081 here
kubectl -n sample-app port-forward svc/sample-api 8081:8000
```

6. Monitoring remediation

```bash
# Monitoring fix is tracked in task-10.
# Summary: pre-seed kube-prometheus-stack CRDs server-side and disable
# prometheusOperator.admissionWebhooks.* in values, then Argo CD Sync with Replace+Prune.
```

## 8. Release Management and Versioning

This section describes the end-to-end release flow for the sample-api service, including how to bump versions, build/push images, select a progressive delivery strategy (blue/green or canary), apply changes with Argo CD, and verify success via CLI and the Argo CD UI.

### 8.1 Version bump workflow

1. Decide new version and image tag (immutable tag recommended):

- Example: v0.2.1

2. Update application version string (visible in /api/version and UI):

- File: apps/sample-api/app/version.py
- Update VersionInfo.version and optionally changelog:
  - See example pattern in [apps/sample-api/app/version.py](apps/sample-api/app/version.py)

3. Build and push the image to GHCR (requires docker logged into ghcr.io):

```bash
IMAGE="ghcr.io/mrthehavok/sample-api"
VERSION="v0.2.1"

# Optional login with env vars if not already logged in:
# echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin

docker build -t "${IMAGE}:${VERSION}" -f apps/sample-api/Dockerfile apps/sample-api
docker push "${IMAGE}:${VERSION}"
```

4. Bump chart metadata (optional but recommended to track appVersion):

- File: charts/sample-api/Chart.yaml
- Set:
  - version: bump chart version (e.g. 0.1.2)
  - appVersion: "0.2.1"

### 8.2 GitOps-first (recommended) — update Helm values and let Argo CD sync

1. Update image tag in chart values:

- File: charts/sample-api/values.yaml
- Keys:
  - .image.repository: ghcr.io/mrthehavok/sample-api
  - .image.tag: "v0.2.1"

2. Select strategy (blue/green or canary):

- For Blue/Green:
  - .rollouts.strategy: blueGreen
  - .rollouts.blueGreen.enabled: true
  - .rollouts.canary.enabled: false
- For Canary:
  - .rollouts.strategy: canary
  - .rollouts.canary.enabled: true
  - .rollouts.canary.steps: define percentage and pause steps

3. Commit and push to the branch watched by the Argo CD Application:

```bash
git add charts/sample-api/values.yaml charts/sample-api/Chart.yaml apps/sample-api/app/version.py
git commit -m "release: sample-api v0.2.1 (values tag, appVersion, app version)"
git push
```

4. Let Argo CD auto-sync or trigger a manual sync from the UI.

5. Pre-flight validation (optional but recommended):

```bash
# Lint and template
helm lint ./charts/sample-api
helm template sample-api ./charts/sample-api --namespace sample-app > /tmp/sample-api.yaml
# API-validate manifests (server-side)
kubectl apply --dry-run=server -n sample-app -f /tmp/sample-api.yaml
```

### 8.3 Argo CD Application parameter override (explicit tag pin)

If you prefer to pin the image tag via the Application params (overriding chart defaults):

- File: infrastructure/argocd/applications/sample-app.yaml
- Ensure:
  - spec.source.helm.parameters:
    - name: image.tag
      value: v0.2.1

Apply and force refresh:

```bash
kubectl -n argocd apply -f infrastructure/argocd/applications/sample-app.yaml
kubectl -n argocd annotate application sample-api argocd.argoproj.io/refresh=hard --overwrite
```

Real-time check of current param:

```bash
kubectl -n argocd get application sample-api \
  -o jsonpath="{.spec.source.helm.parameters[?(@.name=='image.tag')].value}{'\n'}"
```

Notes:

- If both values.yaml and Application helm.parameters specify image.tag, the Application param takes precedence.
- targetRevision can be HEAD or a specific branch. The image.tag param governs the rendered image, independent of Chart.appVersion.

### 8.4 Progressive Delivery: Blue/Green vs Canary

Both strategies are implemented by Argo Rollouts using a Rollout CR rendered from the chart:

- Template: charts/sample-api/templates/rollout.yaml
- Services:
  - Stable: charts/sample-api/templates/service.yaml
  - Blue/Green preview: charts/sample-api/templates/service-preview.yaml
  - Canary service: charts/sample-api/templates/service-canary.yaml

A) Blue/Green

- Configure:
  - values.yaml:
    - rollouts.strategy: blueGreen
    - rollouts.blueGreen.enabled: true
    - rollouts.canary.enabled: false
- Flow:
  - Argo Rollouts creates a preview ReplicaSet and preview Service (…-preview)
  - Verify preview /api/version (via preview service)
  - Promote after verification:
    ```bash
    kubectl argo rollouts promote sample-api -n sample-app
    ```
  - Stable service switches to new RS; old RS scales down per policy.

B) Canary

- Configure:
  - values.yaml:
    - rollouts.strategy: canary
    - rollouts.canary.enabled: true
    - rollouts.canary.steps: e.g.
      ```yaml
      rollouts:
        canary:
          steps:
            - setWeight: 20
            - pause: {}
            - setWeight: 100
      ```
- Flow:
  - Rollout starts canary RS
  - Watch progress:
    ```bash
    kubectl argo rollouts get rollout sample-api -n sample-app --watch
    ```
  - Verify canary Service (…-canary) /api/version
  - Promote to 100%:
    ```bash
    kubectl argo rollouts promote sample-api -n sample-app --full
    ```

### 8.5 Forcing and verifying changes via Argo CD and Helm

1. Force refresh Argo CD app (if UI shows stale data):

```bash
kubectl -n argocd annotate application sample-api \
  argocd.argoproj.io/refresh=hard --overwrite
```

2. GUI checks in Argo CD:

- Applications → sample-api → PARAMETERS tab:
  - image.tag must read v0.2.1
- Tree → Rollout/sample-api → MANIFEST tab:
  - spec.template.spec.containers[0].image must be ghcr.io/mrthehavok/sample-api:v0.2.1
- Pods:
  - Inspect pod image fields; canary pods should be v0.2.1 during a canary rollout
  - After promotion, stable pods should be v0.2.1

3. CLI checks:

```bash
# Rollout status and images
kubectl argo rollouts get rollout sample-api -n sample-app

# Rollout template image
kubectl -n sample-app get rollout sample-api \
  -o jsonpath="{.spec.template.spec.containers[0].image}{'\n'}"

# Pods and their images
kubectl -n sample-app get pods -l app.kubernetes.io/name=sample-api \
  -o jsonpath="{range .items[*]}{.metadata.name}{'\t'}{range .status.containerStatuses[*]}{.image}{end}{'\n'}{end}"

# Service-based functional checks (stable and canary when present)
kubectl -n sample-app run curl-stable --rm -i --restart=Never --image=curlimages/curl:8.10.1 \
  -- curl -sS http://sample-api:8000/api/version

kubectl -n sample-app run curl-canary --rm -i --restart=Never --image=curlimages/curl:8.10.1 \
  -- curl -sS http://sample-api-canary:8000/api/version
```

### 8.6 Rollback

- To previous revision:

```bash
kubectl argo rollouts undo sample-api -n sample-app
# Or explicitly:
# kubectl argo rollouts undo sample-api -n sample-app --to-revision=<N>
```

- Verify:
  - Rollout becomes Healthy
  - spec.template.spec.containers[0].image reflects prior tag
  - Service checks confirm previous app version

### 8.7 Troubleshooting version/tag mismatches

- Symptom: GUI shows old version
  - Action:
    - Refresh app in Argo CD UI
    - Check PARAMETERS for image.tag
    - Ensure Application helm.parameters overrides are set to desired vX.Y.Z
- Symptom: Pods still run old tag after push
  - Action:
    - Confirm image pushed with desired tag to ghcr.io
    - Confirm spec.template image renders to new tag (see CLI checks above)
    - Restart rollout if needed:
      ```bash
      kubectl argo rollouts restart sample-api -n sample-app
      ```
- Symptom: Preview/Canary service still points to old RS
  - Action:
    - Give controller a few seconds to reconcile
    - Verify Service selectors and Endpoints
    - Confirm rollout strategy flags in values.yaml
