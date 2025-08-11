---
id: task-7
title: "Implement CI/CD pipeline with tests & linting"
status: "In Progress"
depends_on: ["task-3", "task-4"]
created: 2025-01-08
updated: 2025-08-11
---

## Description

Implement a basic CI/CD pipeline using GitHub Actions. The pipeline should run on pull requests to lint and test the application and Helm chart.

## Acceptance Criteria

- [ ] GitHub Actions workflow is created.
- [ ] Pipeline is triggered on pull requests to the main branch.
- [ ] A linting job runs for the FastAPI application code.
- [ ] A testing job runs the `pytest` suite for the application.
- [ ] A `helm lint` job runs for the Helm chart.
- [ ] The pipeline status (pass/fail) is reported on the pull request.

## Session History

- 2025-08-11 15:19 UTC: Started work on branch feat/task-7-ci-cd-tests-linting; planned CI workflow for linting (flake8), tests (pytest), and Helm lint.

## Decisions Made

- CI uses GitHub Actions workflow at [".github/workflows/ci.yml"](.github/workflows/ci.yml:1) triggered on pull_request to main for app and chart paths.
- Separate jobs:
  - Python lint/test: flake8 + pytest for [apps/sample-api](apps/sample-api/app/__init__.py:1) and [apps/sample-api/tests](apps/sample-api/tests/__init__.py:1)
  - Helm lint: helm lint for [charts/sample-api](charts/sample-api/Chart.yaml:1)
- Linting configured via [".flake8"](.flake8:1); no image build/push in CI (CD handled by Argo CD).
- Python deps installed from [apps/sample-api/requirements.txt](apps/sample-api/requirements.txt:1); dev extras installed ad-hoc (pytest, flake8) to avoid extra files.
- Keep CI fast: no cluster/minikube boot here; deeper integration runs are addressed separately per ["docs/integration-testing.md"](docs/integration-testing.md:1).

## Files Modified

- [".github/workflows/ci.yml"](.github/workflows/ci.yml:1) (created)
- [".flake8"](.flake8:1) (created)
- ["backlog/tasks/task-6 - Deploy observability stack (kube-prometheus-stack).md"](<backlog/tasks/task-6%20-%20Deploy%20observability%20stack%20(kube-prometheus-stack).md:1>) (status/session updated)
- ["backlog/tasks/task-7 - CI-CD tests & linting.md"](backlog/tasks/task-7%20-%20CI-CD%20tests%20&%20linting.md:1) (status/session updated)

## Blockers

<!-- Document any blockers encountered -->

## Next Steps

- Configure the CI pipeline.
- Add jobs for linting and testing.

## Notes

- This pipeline is for CI (Continuous Integration) only. CD (Continuous Deployment) is handled by Argo CD.
- The pipeline should not build or push container images.
