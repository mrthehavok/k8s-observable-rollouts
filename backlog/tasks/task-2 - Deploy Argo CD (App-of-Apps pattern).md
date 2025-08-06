---
id: task-2
title: "Deploy Argo CD (App-of-Apps pattern)"
status: "In Progress"
depends_on: ["task-1"]
created: 2025-01-08
updated: 2025-01-08
---

## Description

Deploy Argo CD to the Minikube cluster using the App-of-Apps pattern. Configure Argo CD to manage itself and all other applications in the cluster through GitOps practices. Set up the root application that will manage all child applications.

## Acceptance Criteria

- [ ] Argo CD deployed in dedicated `argocd` namespace
- [ ] Root application configured pointing to `argocd-apps/` directory
- [ ] App-of-Apps pattern implemented with proper YAML structure
- [ ] Argo CD UI accessible via port-forward or ingress
- [ ] Admin credentials configured and documented
- [ ] Self-management enabled (Argo CD manages its own configuration)
- [ ] GitHub repository connected as application source
- [ ] Sync policies configured for automatic synchronization

## Session History

- 2025-08-06T16:36:08Z: Branch `feat/task-2-argocd-deploy` created, initial manifests and scripts scaffolded.

## Decisions Made

<!-- Document key implementation decisions -->

## Files Modified

- `argocd/namespace.yaml`
- `argocd/install.yaml`
- `argocd-apps/root-app.yaml`
- `scripts/deploy_argocd.sh`
- `docs/infrastructure-setup.md`

## Blockers

<!-- Document any blockers encountered -->

## Next Steps

- Configure repository credentials in `root-app.yaml`.
- Set up webhook for automatic sync (optional).
- Validate manifests with `kubectl apply --dry-run=client`.

## Notes

- Use declarative setup to ensure reproducibility
- Consider enabling SSO for production use
- Document any custom configurations or patches applied
- May need to configure resource limits for Argo CD components
