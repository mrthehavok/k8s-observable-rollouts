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
