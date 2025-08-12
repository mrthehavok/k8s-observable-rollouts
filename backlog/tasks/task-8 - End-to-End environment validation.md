---
id: task-8
title: "End-to-End environment validation"
status: "Done"
depends_on: ["task-2", "task-4"]
created: 2025-08-09
updated: 2025-08-12
---

## Description

Validate that the full local environment is up and healthy end-to-end with zero errors:

- Kubernetes cluster (Minikube) is running and reachable
- Argo CD is installed, healthy, and App-of-Apps synced
- Argo Rollouts CRDs and controller are installed and healthy
- sample-api Helm chart is deployed via Argo CD and healthy (Rollout + Services)
- Application endpoints are reachable and return expected responses
- Development helpers (scripts/minikube_dev.sh) start/status/stop workflow works correctly

## Acceptance Criteria

- [ ] Minikube cluster:
  - [ ] `minikube status -p <profile>` shows all components running
  - [ ] `kubectl get nodes` shows Ready nodes
- [ ] Argo CD:
  - [ ] Namespace `argocd` exists; core pods are Running and Ready
  - [ ] All Applications are Synced/Healthy
- [ ] Argo Rollouts:
  - [ ] CRD `rollouts.argoproj.io` exists
  - [ ] Namespace `argo-rollouts` exists and controller Deployment is Available
- [ ] sample-api application:
  - [ ] Argo CD `Application/sample-api` is Synced/Healthy
  - [ ] `Rollout/sample-api` exists and is Healthy/Stable in `sample-app` namespace
  - [ ] Stable Service exists; preview/canary Service exists depending on selected strategy
  - [ ] Endpoints populated for the stable Service
- [ ] App reachability and probes:
  - [ ] Port-forwarding is established and `curl http://127.0.0.1:8000/health/ready` returns 200
  - [ ] `/health/live` returns 200
  - [ ] `/metrics` returns text exposition (line count > 0)
- [ ] Dev helper script:

  - [ ] `./scripts/minikube_dev.sh start` starts cluster, dashboard, tunnel, and forwards ports
  - [ ] `./scripts/minikube_dev.sh status` reports all expected components up and forwards active
  - [ ] `./scripts/minikube_dev.sh stop` tears down forwards, dashboard, tunnel, and stops Minikube

- [ ] UI and dashboards:
  - [ ] All dashboards and links open correctly without errors
  - [ ] Argo CD web UI is reachable; all Applications are Synced/Healthy (green) with no warnings or alerts

## Session History

- 2025-08-12T09:10:59Z — Started README planning for unified onboarding.

- 2025-08-12T09:38:00Z — Implemented authoritative root README with end-to-end guide; validated links and commands. Sections added: Overview, TL;DR, Step-by-step Setup, Validation Checklist, Progressive Delivery, Troubleshooting, Cleanup. See [README.md](README.md) and references [scripts/setup_minikube.sh](scripts/setup_minikube.sh), [scripts/minikube_dev.sh](scripts/minikube_dev.sh), [scripts/setup_argocd.sh](scripts/setup_argocd.sh), [scripts/verify_argocd.sh](scripts/verify_argocd.sh), [infrastructure/argocd/applications/app-of-apps.yaml](infrastructure/argocd/applications/app-of-apps.yaml), [infrastructure/argocd/applications/argo-rollouts.yaml](infrastructure/argocd/applications/argo-rollouts.yaml), [infrastructure/argocd/applications/monitoring.yaml](infrastructure/argocd/applications/monitoring.yaml), [infrastructure/argocd/applications/sample-app.yaml](infrastructure/argocd/applications/sample-app.yaml), [infrastructure/monitoring/templates/grafana-datasources.yaml](infrastructure/monitoring/templates/grafana-datasources.yaml), [infrastructure/monitoring/templates/grafana-dashboards.yaml](infrastructure/monitoring/templates/grafana-dashboards.yaml), [apps/sample-api/app/routes/health.py](apps/sample-api/app/routes/health.py), [apps/sample-api/app/routes/info.py](apps/sample-api/app/routes/info.py), [apps/sample-api/app/metrics.py](apps/sample-api/app/metrics.py).
- 2025-08-12T13:12:00Z — Verified sample-app resources: Services sample-api and sample-api-canary (port 8000/TCP), Endpoints populated, Pod Running, and Ingress sample-api.local present via NGINX.
- 2025-08-12T13:15:00Z — Resolved prior Rollout InvalidSpec by setting .Values.rollouts.canary.trafficRouting.nginx.stableIngress to "sample-api" in charts/sample-api/values.yaml; Argo CD Application sample-api Synced/Healthy; Rollout stable.
- 2025-08-12T13:18:00Z — Exposed service via port-forward (kubectl -n sample-app port-forward svc/sample-api 8081:8000); validated HTTP 200 on /health/ready and /version; application reachable locally.
- 2025-08-12T13:20:00Z — Monitoring stack troubleshooting: cleaned residual kube-prometheus-stack admission hook resources; decision taken to move final remediation to task-10 (disable admission webhooks and finalize re-sync). Current state: monitoring namespace Terminating to ensure clean re-create on next pass.
<!-- Update with timestamps and outcomes of validation runs -->

## Decisions Made

- Validate environment using non-destructive checks first (lint/template/kubectl diff where applicable)
- Prefer Argo CD Sync over manual `helm upgrade --install` for app deployment verification
- Manage CRDs outside Helm to avoid patch/immutability conflicts:
  - In Argo CD Applications for argo-rollouts and monitoring set helm.skipCrds: true
  - Pre-seed Prometheus Operator CRDs via: helm show crds prometheus-community/kube-prometheus-stack | kubectl apply --server-side -f -
- Use Argo CD syncOptions for charts with CRDs/hooks: ServerSideApply=true, Replace=true, PrunePropagationPolicy=foreground, PruneLast=true
- For kube-prometheus-stack admission webhooks (hook jobs/resources) plan to disable in values to prevent hook lock:
  - prometheusOperator.admissionWebhooks.enabled: false
  - prometheusOperator.admissionWebhooks.patch.enabled: false
  - Implementation moved to task-10
- Pin argo-rollouts Helm chart targetRevision (2.40.3) instead of HEAD; if selector immutability arises, delete the pre-existing deployment and let Argo CD recreate
- For nginx trafficRouting in Rollout, ensure .Values.rollouts.canary.trafficRouting.nginx.stableIngress = "sample-api"

## Files Modified

- infrastructure/argocd/applications/argo-rollouts.yaml — spec.source.targetRevision pinned to 2.40.3; helm.skipCrds recommended
- infrastructure/argocd/applications/monitoring.yaml — helm.skipCrds: true and syncOptions (ServerSideApply, Replace, PrunePropagationPolicy=foreground, PruneLast)
- charts/sample-api/values.yaml — rollouts.canary.trafficRouting.nginx.stableIngress: "sample-api"
- README.md — reformatted "My commands" section for clarity and copy-pasteability; added comments and alt port-forward (8081)
- scripts/minikube_dev.sh (exists; used for start/status/stop workflow)

## Blockers

- Monitoring application: kube-prometheus-stack sync stuck due to admission webhook hook resources; remediation moved to task-10 (disable admission webhooks, finalize re-sync)
- If GHCR images are private, cluster must have imagePullSecrets configured (documented in README)
- Argo CD must be installed and App-of-Apps applied prior to validation

## Next Steps

- Create and execute task-10 — Fix monitoring stack sync hooks issues: pre-seed CRDs (server-side), disable admission webhooks in infrastructure/monitoring/values.yaml, re-apply Application, Argo CD Sync (Prune+Replace), verify pods and UIs
- Polish README "My commands" section (structured blocks, comments, alternate ports) to reflect the working sequence
- Validate dev helper script workflow: ./scripts/minikube_dev.sh start | status | stop
- Re-run acceptance checks; when all Applications are green, mark task-8 "Done"
