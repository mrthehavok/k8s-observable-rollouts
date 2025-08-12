---
id: task-10
title: "Fix monitoring stack sync hooks and finalize observability"
status: "In Progress"
depends_on: ["task-8"]
created: 2025-08-12
updated: 2025-08-12
---

## Description

Monitoring application (kube-prometheus-stack) intermittently sticks in Argo CD Sync due to Helm admission webhook hook resources and CRD lifecycle ordering. This task extracts the remediation from task-8 into a dedicated ticket to complete a clean, GitOps-managed deployment of the observability stack and verify UIs.

Key goals:

- Manage Prometheus Operator CRDs outside of Helm (pre-seed with server-side apply).
- Disable kube-prometheus-stack admission webhook hooks to avoid lingering hook resources.
- Keep Argo CD as the single reconciliation engine with safe syncOptions.
- Achieve a Synced/Healthy state for the monitoring application and verify Grafana/Prometheus UIs.

## Acceptance Criteria

- [ ] Argo CD Application `monitoring` is Synced and Healthy.
- [ ] Monitoring namespace recreated if previously Terminating; no orphaned hook resources remain:
  - [ ] No `kube-prometheus-stack-admission` jobs, service accounts, secrets, clusterroles/clusterrolebindings, or webhook configurations.
- [ ] Prometheus Operator CRDs present and reconciled without patch conflicts:
  - [ ] servicemonitors.monitoring.coreos.com
  - [ ] podmonitors.monitoring.coreos.com
  - [ ] prometheusrules.monitoring.coreos.com
  - [ ] alertmanagers.monitoring.coreos.com
  - [ ] probes.monitoring.coreos.com
- [ ] Core Pods Running/Ready in `monitoring` namespace:
  - [ ] kube-prometheus-stack-operator
  - [ ] kube-prometheus-stack-prometheus
  - [ ] kube-prometheus-stack-alertmanager
  - [ ] kube-prometheus-stack-grafana
- [ ] Grafana reachable via port-forward: `http://localhost:3000/` (dashboard loads).
- [ ] Prometheus reachable via port-forward: `http://localhost:9090/` (targets show expected endpoints).
- [ ] Argo Rollouts dashboard is accessible locally and lists `Rollout/sample-api` with correct status.

## Session History

- 2025-08-12T13:20:00Z — Spun off from task-8 after removing residual admission hook resources and deciding to finalize remediation separately.
- 2025-08-12T13:25:00Z — Documented plan to disable admission webhooks and pre-seed CRDs via server-side apply.
- 2025-08-12T16:12:16Z — Set status to In Progress; created docs/observability.md entry-point and prepared YAML changes to disable admission webhooks; proceeding per plan.

## Decisions Made

- Manage CRDs outside Helm:
  - Use `helm show crds prometheus-community/kube-prometheus-stack | kubectl apply --server-side -f -`
  - Keep `helm.skipCrds: true` in Argo CD Application for monitoring.
- Disable Helm admission webhook hooks to avoid stuck syncs:
  - `prometheusOperator.admissionWebhooks.enabled: false`
  - `prometheusOperator.admissionWebhooks.patch.enabled: false`
- Prefer GitOps flow:
  - Update repo values and Argo CD Application configuration, then Sync with `Replace` + `Prune`.

## Files Modified

- infrastructure/monitoring/values.yaml — disable admission webhooks:
  - `prometheusOperator.admissionWebhooks.enabled: false`
  - `prometheusOperator.admissionWebhooks.patch.enabled: false`
- infrastructure/argocd/applications/monitoring.yaml — ensure:
  - `spec.source.helm.skipCrds: true`
  - `spec.syncPolicy.syncOptions` includes:
    - `ServerSideApply=true`
    - `Replace=true`
    - `PrunePropagationPolicy=foreground`
    - `PruneLast=true`
- README.md — optional: add refined instructions for observability access/verification (port-forward, basic checks).

## Plan

1. Ensure a clean namespace state

```bash
# If monitoring ns is Terminating, ensure no finalizers are blocking; otherwise recreate
kubectl get ns monitoring || kubectl create namespace monitoring
```

2. Pre-seed Prometheus Operator CRDs using server-side apply

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm show crds prometheus-community/kube-prometheus-stack | kubectl apply --server-side -f -
```

3. Disable admission webhooks in values (repo-managed)

```yaml
# infrastructure/monitoring/values.yaml
prometheusOperator:
  admissionWebhooks:
    enabled: false
    patch:
      enabled: false
```

4. Re-apply Argo CD Application and Sync

```bash
kubectl -n argocd apply -f infrastructure/argocd/applications/monitoring.yaml
# In Argo CD UI: Sync with Prune + Replace
# Or via CLI if available:
# argocd app sync monitoring --prune --replace --timeout 600
```

5. Verify resources and health

```bash
kubectl -n monitoring get pods -o wide
kubectl -n monitoring get events --sort-by=.lastTimestamp | tail -n 100
kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations | grep kube-prometheus-stack || echo "No monitoring admission webhooks"
kubectl get clusterrole,clusterrolebinding | grep kube-prometheus-stack-admission || echo "No admission RBAC"
```

6. Access UIs (port-forward)

```bash
# Prometheus
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090

# Grafana
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

# Argo Rollouts dashboard (requires kubectl-argo-rollouts plugin)
# This starts a local UI and prints a URL such as http://localhost:3100
# Use --port to change port if needed, e.g., --port=3101
kubectl argo rollouts dashboard -n sample-app
```

## Blockers

- If namespace `monitoring` is stuck in Terminating due to finalizers on namespaced objects:
  - Identify and clean remaining resources (secrets, jobs, SA) related to `kube-prometheus-stack-admission`.
- If CRD apply fails with annotation size errors:
  - Always use `kubectl apply --server-side` as above; client-side apply can fail on large annotations.
- If Grafana default credentials differ from expectations:
  - Check chart values and Kubernetes Secret created by the chart for admin credentials.

## Next Steps

- Implement value changes and re-apply the monitoring Application.
- Complete Argo CD Sync with Replace + Prune and verify that all pods are Running/Ready.
- Port-forward Grafana and Prometheus and validate dashboards and targets; launch Argo Rollouts dashboard and verify `Rollout/sample-api` is visible with expected status.
- Update this task with outcomes and mark **Done** when acceptance criteria are met.

## Notes

- This task is a continuation of the environment hardening from task-8; it aims to keep GitOps flows smooth by removing Helm hook-induced drift and CRD patch conflicts.
