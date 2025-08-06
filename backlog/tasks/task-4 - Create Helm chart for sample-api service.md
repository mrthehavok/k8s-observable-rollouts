---
id: task-4
title: "Create Helm chart for sample-api service"
status: "To Do"
depends_on: ["task-3"]
created: 2025-01-08
updated: 2025-01-08
---

## Description

Create a simplified Helm chart for the FastAPI sample microservice for a single environment. The chart should follow basic Helm best practices and integrate with Argo CD and Argo Rollouts.

## Acceptance Criteria

- [ ] Helm chart structure follows official best practices
- [ ] A single `values.yaml` for configuration.
- [ ] Deployment manifest with basic resource limits/requests.
- [ ] Service manifest to expose the application.
- [ ] ConfigMap for application configuration.
- [ ] Chart is installable and passes `helm lint`.
- [ ] README.md with basic usage instructions.

## Session History

<!-- Update as work progresses -->

## Decisions Made

<!-- Document key implementation decisions -->

## Files Modified

<!-- Track all file changes -->

## Blockers

<!-- Document any blockers encountered -->

## Next Steps

- Define chart metadata.
- Create templates for Deployment, Service, and ConfigMap.
- Ensure chart supports a `Rollout` resource as an alternative to `Deployment`.

## Notes

- Use Helm 3.x features.
- The chart will be for a single-environment deployment (Minikube).
- Ensure chart supports both Deployment and Rollout resources.
