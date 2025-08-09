# sample-api Helm Chart (dev-only)

Minimal Helm chart for the FastAPI sample microservice targeting a single dev environment (Minikube). Workload uses Argo Rollouts with selectable strategies: blue-green (default) or canary. No extra templates (no Ingress, HPA, ServiceMonitor, or ConfigMap).

## Contents

- Workload: Argo Rollouts Rollout
- Services:
  - Stable Service
  - Preview Service (blue-green)
  - Canary Service (canary)

## Prerequisites

- Helm 3.x
- Kubernetes cluster (e.g., Minikube)
- Argo Rollouts CRDs and controller installed

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argo-rollouts argo/argo-rollouts --namespace argo-rollouts --create-namespace --wait
```

## Quickstart

Install with default blue-green strategy:

```bash
helm upgrade --install sample-api ./charts/sample-api \
  --namespace sample-app --create-namespace
```

Switch to canary strategy:

```bash
helm upgrade --install sample-api ./charts/sample-api \
  --namespace sample-app --create-namespace \
  --set rollouts.strategy=canary
```

Port-forward stable service:

```bash
kubectl -n sample-app port-forward svc/sample-api 8000:8000
curl -s http://127.0.0.1:8000/health/ready
```

## Values

Key settings (see values.yaml for full list):

```yaml
replicaCount: 1

image:
  repository: sample-api
  tag: "latest"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8000

ports:
  http:
    name: http
    containerPort: 8000

# Probes wired to app endpoints
probes:
  liveness:
    enabled: true
    path: /health/live
    initialDelaySeconds: 5
    periodSeconds: 10
  readiness:
    enabled: true
    path: /health/ready
    initialDelaySeconds: 5
    periodSeconds: 10
  startup:
    enabled: false
    path: /health/startup
    failureThreshold: 30
    periodSeconds: 10

# Prometheus scrape annotations (applied to Pod)
metrics:
  enabled: true
  path: /metrics
  scrape:
    enabled: true

# Argo Rollouts configuration
rollouts:
  enabled: true
  strategy: blueGreen # Options: blueGreen | canary
  canary:
    steps: [] # e.g., [{ setWeight: 20 }, { pause: { duration: 10 } }]
  blueGreen:
    autoPromotionEnabled: true
    autoPromotionSeconds: 0

# Optional environment variables
env: []
extraEnvFrom: []
```

## Lint and Render

```bash
helm lint charts/sample-api
helm template charts/sample-api -f charts/sample-api/values.yaml | less
```

Validate server-side (if cluster context is available):

```bash
helm template charts/sample-api -f charts/sample-api/values.yaml > /tmp/sample-api.yaml
kubectl apply --dry-run=server -f /tmp/sample-api.yaml
```

## Notes

- Dev-only scope; no Ingress/ServiceMonitor/HPA/ConfigMap.
- Blue-green uses a preview service: sample-api-preview
- Canary uses a canary service: sample-api-canary

## GHCR (GitHub Container Registry) flow

This chart is configured to use GHCR for the container image.

- Default image repository: `ghcr.io/mrthehavok/sample-api` (set in values.yaml)
- Default pull policy: Always (useful for dev to always fetch latest tags)

### 1) Build and push image to GHCR (via GitHub Actions)

A workflow is provided:

- [.github/workflows/build-and-push-ghcr.yml](../.github/workflows/build-and-push-ghcr.yml)

It:

- logs in to GHCR with GITHUB_TOKEN,
- builds the image from `apps/sample-api/Dockerfile`,
- pushes tags (latest on default branch, branch name, short SHA, semver on tags).

No manual steps are required if you merge to main; GHCR will contain tags like:

- `ghcr.io/mrthehavok/sample-api:latest` (default branch)
- `ghcr.io/mrthehavok/sample-api:<branch>`
- `ghcr.io/mrthehavok/sample-api:sha-<short>`
- `ghcr.io/mrthehavok/sample-api:vX.Y.Z` (when you push a git tag)

### 2) Deploy with Helm using GHCR image

- Ensure the desired tag exists in GHCR (via CI run or manual build).
- Install chart (blue-green by default):

```bash
helm upgrade --install sample-api ./charts/sample-api \
  --namespace sample-app --create-namespace \
  --set image.repository=ghcr.io/mrthehavok/sample-api \
  --set image.tag=latest
```

- Switch rollout strategy to canary if needed:

```bash
helm upgrade --install sample-api ./charts/sample-api \
  --namespace sample-app --create-namespace \
  --set rollouts.strategy=canary \
  --set image.repository=ghcr.io/mrthehavok/sample-api \
  --set image.tag=latest
```

### 3) If GHCR package is private (pull secrets)

Create a docker-registry secret in the target namespace:

```bash
kubectl create secret docker-registry ghcr-creds \
  --docker-server=ghcr.io \
  --docker-username=mrthehavok \
  --docker-password="<YOUR_GHCR_TOKEN>" \
  --namespace sample-app
```

Then provide it to the chart either via values.yaml:

```yaml
imagePullSecrets:
  - name: ghcr-creds
```

or via CLI:

```bash
helm upgrade --install sample-api ./charts/sample-api \
  --namespace sample-app --create-namespace \
  --set image.repository=ghcr.io/mrthehavok/sample-api \
  --set image.tag=latest \
  --set imagePullSecrets[0].name=ghcr-creds
```
