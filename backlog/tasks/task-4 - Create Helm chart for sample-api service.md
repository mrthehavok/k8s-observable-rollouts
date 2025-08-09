---
id: task-4
title: "Create Helm chart for sample-api service"
status: "Done"
depends_on: ["task-3"]
created: 2025-01-08
updated: 2025-08-09
---

## Description

Dev-only Helm chart for the FastAPI sample microservice with minimal resources, targeting Minikube. No extra templates beyond the workload and services. Workload uses Argo Rollouts with two selectable strategies: blue-green or canary. Single values.yaml; Helm 3.x features only.

## Acceptance Criteria

- [ ] Dev-only chart with minimal structure (Chart.yaml, values.yaml, templates/\_helpers.tpl, templates/rollout.yaml, templates/service.yaml, templates/service-preview.yaml for blue/green, templates/service-canary.yaml for canary).
- [ ] Single values.yaml controlling image, service, and rollout strategy (rollout.enabled, rollout.strategy: blueGreen|canary; canary steps configurable).
- [ ] Workload rendered as Argo Rollouts Rollout (no Deployment).
- [ ] Service exposes the app; preview or canary service is rendered depending on strategy.
- [ ] Chart passes helm lint; helm template renders cleanly; kubectl apply --dry-run=server validates rendered manifests.
- [ ] README.md documents quickstart and how to select blue-green or canary.
- [ ] No ConfigMap, Ingress, ServiceMonitor, HPA in this task scope.

## Session History

- 2025-08-08T15:12:43+02:00: Updated scope to dev-only without extra templates; keep Argo Rollouts with blue-green and canary strategies. Status set to In Progress.
- 2025-08-08T15:49:20+02:00: Implemented rollout.yaml, service.yaml, service-preview.yaml, service-canary.yaml; updated values.yaml to enable rollouts (blueGreen default).
- 2025-08-08T15:50:37+02:00: Verified helm lint and rendered both blue-green and canary via helm template.
- 2025-08-08T15:51:35+02:00: Added charts/sample-api/README.md (quickstart and strategy selection).
- 2025-08-08T15:52:45+02:00: All acceptance criteria met; marking task Done.
- 2025-08-09T14:19:38+02:00: Deferred further cluster/ArgoCD troubleshooting to follow-up tasks; created plan for E2E validation and rollout tests.

## Decisions Made

- Scope narrowed to a single dev environment (Minikube).
- Use Argo Rollouts Rollout as the only workload resource; exclude Deployment.
- Minimize templates: only workload and services needed for selected strategy.
- Exclude ConfigMap, Ingress, ServiceMonitor, HPA for this task.
- Maintain a single values.yaml (no env-specific values files).

## Files Modified

- charts/sample-api/values.yaml (updated)
- charts/sample-api/templates/rollout.yaml (created)
- charts/sample-api/templates/service.yaml (created)
- charts/sample-api/templates/service-preview.yaml (created)
- charts/sample-api/templates/service-canary.yaml (created)
- charts/sample-api/README.md (created)
- backlog/tasks/task-4 - Create Helm chart for sample-api service.md (updated)

## Blockers

- None at this time.

## Next Steps

- Create and execute task-8: E2E environment validation (cluster, Argo CD apps, rollouts controller, app reachability, metrics) with zero errors.
- Create and execute task-9: Deploy new version using blue-green and canary strategies via Argo Rollouts; validate rollout success and rollback paths.

## Notes

- Helm 3.x only.
- Target: Minikube dev environment.
- Keep naming/labels consistent with helpers.
