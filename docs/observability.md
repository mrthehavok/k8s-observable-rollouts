# Observability Quick Start

This guide provides the shortest path to a green monitoring application in Argo CD, accessible Grafana dashboards, and verified Prometheus targets. For the full stack design and advanced configuration, see [Observability Stack Deployment](./observability-stack.md).

## Prerequisites

- A running Kubernetes cluster (Minikube recommended for local).
- Argo CD installed and accessible.
- This repository applied as the GitOps source.

## One-time CRD pre-seeding

Prometheus Operator CRDs are large and can fail with client-side apply or hook ordering. Pre-seed them with server-side apply:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm show crds prometheus-community/kube-prometheus-stack | kubectl apply --server-side -f -
```

## Sync the monitoring application

Ensure admission webhook hooks are disabled in the chart values (added in this repo):

- kube-prometheus-stack.prometheusOperator.admissionWebhooks.enabled=false
- kube-prometheus-stack.prometheusOperator.admissionWebhooks.patch.enabled=false

Then re-apply and sync:

```bash
kubectl -n argocd apply -f infrastructure/argocd/applications/monitoring.yaml
# In Argo CD UI: Sync with Prune + Replace
# Or via CLI if available:
# argocd app sync monitoring --prune --replace --timeout 600
```

## Verify health and resources

```bash
# Core pods
kubectl -n monitoring get pods -o wide

# Events
kubectl -n monitoring get events --sort-by=.lastTimestamp | tail -n 100

# No lingering admission hook resources
kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations | grep kube-prometheus-stack || echo "No monitoring admission webhooks"
kubectl get clusterrole,clusterrolebinding | grep kube-prometheus-stack-admission || echo "No admission RBAC"

# CRDs present
kubectl get crd | grep -E "servicemonitors|podmonitors|prometheusrules|alertmanagers|probes"
```

## Access UIs

Grafana:

```bash
# Ingress (Minikube): http://grafana.local
# Or via port-forward:
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
# Open http://localhost:3000 (admin/admin by default for local dev)
```

Prometheus:

```bash
# Ingress (Minikube): http://prometheus.local
# Or via port-forward:
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/targets to verify scrapes
```

Argo Rollouts dashboard (local UI):

```bash
kubectl argo rollouts dashboard -n sample-app
```

## Dashboards

The repository provisions Grafana dashboards via ConfigMaps and the Grafana sidecar:

- Application: Sample API Overview
- Infrastructure: Argo CD Overview
- Rollouts: Argo Rollouts Overview

Folders are created by the sidecar via target directories:

- /var/lib/grafana/dashboards/application
- /var/lib/grafana/dashboards/infrastructure
- /var/lib/grafana/dashboards/rollouts

## Quick checks

```bash
# Argo CD app status
kubectl -n argocd get application monitoring

# Grafana datasources
kubectl -n monitoring get cm grafana-datasources -o yaml | grep -E "Prometheus|Alertmanager"

# Prometheus targets
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090/targets and ensure Argo CD, Argo Rollouts, and Sample API targets are up
```

## Troubleshooting

- Namespace monitoring stuck Terminating: delete residual kube-prometheus-stack-admission jobs, SA, secrets, and RBAC; then recreate the namespace.
- CRD apply errors: always use server-side apply as shown above.
- Grafana login: for local dev the default is admin/admin unless overridden by chart values.
- Argo CD stays OutOfSync: ensure admission webhooks are disabled in values and run Sync with Replace + Prune.

## References

- Full guide: [Observability Stack Deployment](./observability-stack.md)
- Monitoring application: infrastructure/argocd/applications/monitoring.yaml
- Values: infrastructure/monitoring/values.yaml
- Datasources: infrastructure/monitoring/templates/grafana-datasources.yaml
- Dashboards: infrastructure/monitoring/templates/grafana-dashboards.yaml
- ServiceMonitors: infrastructure/monitoring/templates/servicemonitor-argocd.yaml, infrastructure/monitoring/templates/servicemonitor-rollouts.yaml, infrastructure/monitoring/templates/servicemonitor-sample-api.yaml
