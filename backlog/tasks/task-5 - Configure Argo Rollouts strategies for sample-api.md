---
id: task-5
title: "Configure Argo Rollouts strategies for sample-api"
status: "Done"
depends_on: ["task-2", "task-4"]
created: 2025-01-08
updated: 2025-08-11
---

## Description

Configure Argo Rollouts to manage progressive delivery of the sample-api service. Implement canary and blue-green rollout strategies.

## Acceptance Criteria

- [ ] Argo Rollouts controller deployed and operational. → Moved to task-9.
- [x] `Rollout` resource defined for the sample-api service.
- [x] Canary strategy configured with traffic splitting.
- [x] Blue-green strategy configured with a preview service.
- [x] Integration with the ingress controller for traffic management.
- [x] Basic rollback and promotion policies are configured.
- [ ] Rollout dashboard is accessible for monitoring. → Moved to task-9.
- [ ] A basic `AnalysisTemplate` is configured for automated canary analysis (e.g., checking error rates). → Moved to task-6.

## Session History

- 2025-08-11 09:52 UTC: Added rollbackWindow and restart-on-change annotations in [charts/sample-api/templates/rollout.yaml](charts/sample-api/templates/rollout.yaml:1) and wired values in [charts/sample-api/values.yaml](charts/sample-api/values.yaml:66). Committed feat(rollouts).
- 2025-08-11 10:23 UTC: Added Qdrant background service controls to [scripts/minikube_dev.sh](scripts/minikube_dev.sh:1). Committed feat(dev).
- 2025-08-11 10:58 UTC: Opened PR [#13](https://github.com/mrthehavok/k8s-observable-rollouts/pull/13) for review.
- 2025-08-11 11:13 UTC: Closed task-5; moved live verification to [backlog/tasks/task-9 - Test progressive delivery (blue-green and canary).md](<backlog/tasks/task-9%20-%20Test%20progressive%20delivery%20(blue-green%20and%20canary).md>) and AnalysisTemplate work to [backlog/tasks/task-6 - Deploy observability stack (kube-prometheus-stack).md](<backlog/tasks/task-6%20-%20Deploy%20observability%20stack%20(kube-prometheus-stack).md>).

## Decisions Made

- Use Rollout CRD via Helm to support both canary and blue-green with `.Values.rollouts.strategy` selector.
- Drive `spec.rollbackWindow.revisions` and restart annotations from `.Values.rollouts` for configurable policies.
- Integrate NGINX traffic routing for canary using stable ingress set to chart fullname.

## Files Modified

- [charts/sample-api/templates/rollout.yaml](charts/sample-api/templates/rollout.yaml:1)
- [charts/sample-api/values.yaml](charts/sample-api/values.yaml:66)
- [scripts/minikube_dev.sh](scripts/minikube_dev.sh:1)
- [backlog/tasks/task-5 - Configure Argo Rollouts strategies for sample-api.md](backlog/tasks/task-5%20-%20Configure%20Argo%20Rollouts%20strategies%20for%20sample-api.md)

## Blockers

- None (remaining verification and analysis items moved to their respective tasks).

## Next Steps

- Follow-up handled in:
  - [backlog/tasks/task-6 - Deploy observability stack (kube-prometheus-stack).md](<backlog/tasks/task-6%20-%20Deploy%20observability%20stack%20(kube-prometheus-stack).md>): add a basic AnalysisTemplate and wire optional canary analysis.
  - [backlog/tasks/task-9 - Test progressive delivery (blue-green and canary).md](<backlog/tasks/task-9%20-%20Test%20progressive%20delivery%20(blue-green%20and%20canary).md>): perform live verification of the Argo Rollouts controller and dashboard accessibility.

## Notes

- Use Rollout resource instead of Deployment in Helm chart
- Consider using Istio for more advanced traffic management
- Document rollback procedures and emergency protocols
- Test all strategies in dev environment first
- Ensure compatibility with HPA and pod disruption budgets
