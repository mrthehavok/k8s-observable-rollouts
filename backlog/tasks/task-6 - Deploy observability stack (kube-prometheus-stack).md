---
id: task-6
title: "Deploy observability stack (kube-prometheus-stack)"
status: "To Do"
depends_on: ["task-2"]
created: 2025-01-08
updated: 2025-08-11
---

## Description

Deploy a comprehensive observability stack using kube-prometheus-stack (Prometheus, Grafana, Alertmanager). Configure monitoring for all components including Kubernetes cluster, Argo CD, Argo Rollouts, and the sample application. Set up dashboards and alerts for operational visibility.

## Acceptance Criteria

- [ ] kube-prometheus-stack deployed via Argo CD
- [ ] Prometheus configured with appropriate retention
- [ ] Grafana accessible with pre-configured dashboards
- [ ] Alertmanager configured with notification channels
- [ ] ServiceMonitors created for all applications
- [ ] Custom dashboards for Argo CD and Rollouts
- [ ] Application-specific dashboard for sample-api
- [ ] Critical alerts defined and tested
- [ ] Metrics storage optimized for local environment
- [ ] Basic AnalysisTemplate for automated canary analysis is defined and available for Argo Rollouts

## Session History

<!-- Update as work progresses -->

## Decisions Made

<!-- Document key implementation decisions -->

## Files Modified

<!-- Track all file changes -->

## Blockers

<!-- Document any blockers encountered -->

## Next Steps

- Create values file for kube-prometheus-stack
- Design dashboard layouts for key metrics
- Define SLIs/SLOs for sample application
- Configure persistent storage for metrics
- Create a basic Argo Rollouts AnalysisTemplate and wire Helm values to enable/parameterize it; plan to reference it from canary steps later

## Notes

- Consider using Thanos for long-term storage in production
- Optimize resource usage for Minikube environment
- Import community dashboards for common components
- Document metric naming conventions
- Set up recording rules for complex queries
