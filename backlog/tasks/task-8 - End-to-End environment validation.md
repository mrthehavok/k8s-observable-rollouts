---
id: task-8
title: "End-to-End environment validation"
status: "To Do"
depends_on: ["task-2", "task-4"]
created: 2025-08-09
updated: 2025-08-11
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

<!-- Update with timestamps and outcomes of validation runs -->

## Decisions Made

- Validate environment using non-destructive checks first (lint/template/kubectl diff where applicable)
- Prefer Argo CD Sync over manual `helm upgrade --install` for app deployment verification

## Files Modified

- scripts/minikube_dev.sh (exists; used for start/status/stop workflow)

## Blockers

- If GHCR images are private, cluster must have imagePullSecrets configured (documented in README)
- Argo CD must be installed and App-of-Apps applied prior to validation

## Next Steps

- Execute validation checklist and record results in Session History
- Address any findings (CRDs missing, Application OutOfSync/Missing, image pull issues, etc.)
