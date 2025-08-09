---
id: task-9
title: "Test progressive delivery (blue-green and canary)"
status: "To Do"
depends_on: ["task-8"]
created: 2025-08-09
updated: 2025-08-09
---

## Description

Test the full progressive delivery workflow for the sample-api application using Argo Rollouts. This includes:

- Deploying a new version of the application (v2)
- Validating the blue-green deployment strategy (preview service, promotion)
- Validating the canary deployment strategy (traffic splitting, analysis, promotion)
- Validating successful rollback to the previous version

## Acceptance Criteria

- [ ] **Setup:**
  - [ ] A new version of the application is built and pushed to GHCR (e.g., with a visible change like a version bump in the UI or API response).
- [ ] **Blue-Green Strategy:**
  - [ ] Argo CD Application is updated to use the new image tag.
  - [ ] A new ReplicaSet (preview) is created and becomes healthy.
  - [ ] The `*-preview` Service correctly routes traffic to the new version.
  - [ ] The stable Service continues to route traffic to the old version.
  - [ ] Manual promotion (`kubectl argo rollouts promote`) successfully switches traffic to the new version.
  - [ ] The old ReplicaSet is scaled down.
- [ ] **Canary Strategy:**
  - [ ] Argo CD Application is updated to use the canary strategy (`rollouts.strategy=canary`).
  - [ ] A new ReplicaSet (canary) is created.
  - [ ] Traffic is split between stable and canary services according to the steps in `values.yaml`.
  - [ ] Manual promotion successfully shifts all traffic to the new version.
- [ ] **Rollback:**
  - [ ] A rollback can be successfully triggered (`kubectl argo rollouts undo`).
  - [ ] Traffic is fully restored to the previous stable version.
- [ ] **Documentation:**
  - [ ] Session History is updated with commands used and observed outcomes for each test case.

## Session History

<!-- Update with timestamps, commands, and outcomes for each test -->

## Decisions Made

- Use a simple, observable change for the new application version (e.g., update `version.py`).
- Perform tests manually using `kubectl` and `kubectl argo rollouts` commands to closely monitor the process.

## Files Modified

- `apps/sample-api/app/version.py` (or similar file to create a new version)
- `charts/sample-api/values.yaml` (to change `image.tag` and `rollouts.strategy`)

## Blockers

- The E2E environment from task-8 must be fully healthy and validated before starting.

## Next Steps

- Create a new application version and push the image to GHCR.
- Execute the blue-green test plan.
- Execute the canary test plan.
- Execute the rollback test.
- Document all steps and results.
