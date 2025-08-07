---
id: task-2
title: "Deploy Argo CD (App-of-Apps pattern)"
status: "Done"
depends_on: ["task-1"]
created: 2025-01-08
updated: 2025-08-07
---

## Description

Deploy Argo CD to the Minikube cluster using the App-of-Apps pattern. Configure Argo CD to manage itself and all other applications in the cluster through GitOps practices. Set up the root application that will manage all child applications.

## Acceptance Criteria

- [x] Argo CD deployed in dedicated `argocd` namespace
- [x] Root application configured pointing to `argocd-apps/` directory
- [x] App-of-Apps pattern implemented with proper YAML structure
- [x] Argo CD UI accessible via port-forward or ingress
- [x] Admin credentials configured and documented
- [x] Self-management enabled (Argo CD manages its own configuration)
- [x] GitHub repository connected as application source
- [x] Sync policies configured for automatic synchronization

## Session History

- 2025-08-06T16:36:08Z: Branch `feat/task-2-argocd-deploy` created, initial manifests and scripts scaffolded.
- 2025-08-06T17:50:00Z: Reset repository to a known good state and switched to remote manifest for Argo CD installation to resolve deployment issues.
- 2025-08-06T17:55:00Z: Successfully deployed Argo CD using the remote manifest and verified UI access.
- 2025-08-07 14:30: Re-installed Argo CD via remote install.yaml; removed Helm chart approach; verified service label fix; cluster healthy.

## Decisions Made

- Simplified Argo CD install to remote manifest to avoid Helm selector immutability issues.

## Files Modified

- `scripts/setup_argocd.sh` (modified)
- `docs/infrastructure-setup.md` (modified)
- `infrastructure/argocd/values.yaml` (removed)

## Blockers

<!-- Document any blockers encountered -->

## Next Steps

- None – task closed.

## Notes

- Use declarative setup to ensure reproducibility
- Consider enabling SSO for production use
- Document any custom configurations or patches applied
- May need to configure resource limits for Argo CD components
