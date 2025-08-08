---
id: task-3
title: "Develop FastAPI sample microservice"
status: "Done"
depends_on: []
created: 2025-01-08
updated: 2025-08-08
---

## Description

Develop a sample FastAPI microservice that will serve as the target application for demonstrating progressive delivery with Argo Rollouts. The service includes health endpoints, metrics exposure, version and demo endpoints with feature flags, and unit tests. Code is formatted and linted to pass CI.

## Acceptance Criteria

- [x] FastAPI application with REST endpoints implemented
- [x] Health check endpoints (/health/live, /health/ready, /health/startup) configured
- [x] Prometheus metrics endpoint exposed (/metrics)
- [x] Version endpoint returning current application version
- [x] Feature flag endpoints to simulate different behaviors (demo/slow, demo/error, demo/cpu, demo/memory)
- [ ] Unit tests with ≥ 80 % coverage (tests pass; add coverage gate)
- [ ] Dockerfile optimized for production use (baseline exists; optimization pending)
- [x] Configuration via environment variables (pydantic-settings)
- [ ] Structured logging with correlation IDs

## Session History

- 2025-08-07: Resolved Python environment issues (PEP 668) and created local venv. Addressed Python 3.13 incompatibilities by unpinning legacy requirements and installing compatible versions; added psutil.
- 2025-08-07: Implemented request metrics middleware [RequestMetricsMiddleware](apps/sample-api/app/middleware.py) and Prometheus registry [MetricsRegistry](apps/sample-api/app/metrics.py).
- 2025-08-07: Implemented health models [HealthStatus](apps/sample-api/app/models/health.py), [ComponentHealth](apps/sample-api/app/models/health.py), [HealthCheck](apps/sample-api/app/models/health.py), [ReadinessCheck](apps/sample-api/app/models/health.py).
- 2025-08-07: Implemented version models [VersionInfo](apps/sample-api/app/models/info.py), [AppInfo](apps/sample-api/app/models/info.py), and app version source [version_info](apps/sample-api/app/version.py).
- 2025-08-07: Implemented root router [router](apps/sample-api/app/routes/root.py) and fixed static assets mounting with absolute path in [app.main:lifespan()](apps/sample-api/app/main.py:15) and static mount in [app.main](apps/sample-api/app/main.py).
- 2025-08-07: Implemented and corrected health routes [health](apps/sample-api/app/routes/health.py) to return proper models and statuses ("ok"/"error").
- 2025-08-07: Added metrics endpoint (/metrics) in [app.main](apps/sample-api/app/main.py) using [metrics_registry.get_metrics()](apps/sample-api/app/metrics.py).
- 2025-08-07: Implemented info route [get_version](apps/sample-api/app/routes/info.py) and [get_info](apps/sample-api/app/routes/info.py), aligning fields with VersionInfo (build_number, environment).
- 2025-08-07: Updated tests [tests/test_api.py](apps/sample-api/tests/test_api.py) to align with new response schemas; all tests pass (7 passed).
- 2025-08-07–2025-08-08: Fixed flake8 errors (E302/E304/E501/etc.), applied isort and black across the app to satisfy CI formatting/linting.

## Decisions Made

- Adopted Pydantic v2 models and pydantic-settings for config loading.
- Implemented metrics via prometheus_client with a dedicated registry and middleware to track counts, durations, sizes, and active requests.
- Used a FastAPI middleware [RequestMetricsMiddleware](apps/sample-api/app/middleware.py) for uniform metrics collection.
- Used absolute path for static assets to ensure tests and CLI runs can locate static directory reliably.
- Relaxed strict requirement pins to allow Python 3.13-compatible wheels; will reintroduce controlled pinning with constraints/lockfiles later.
- Standardized formatting (black + isort) and addressed flake8 findings to prevent CI failures on style.

## Files Modified

- apps/sample-api/requirements.txt
- apps/sample-api/app/main.py
- apps/sample-api/app/middleware.py
- apps/sample-api/app/metrics.py
- apps/sample-api/app/models/health.py
- apps/sample-api/app/models/info.py
- apps/sample-api/app/version.py
- apps/sample-api/app/routes/root.py
- apps/sample-api/app/routes/health.py
- apps/sample-api/app/routes/info.py
- apps/sample-api/tests/conftest.py
- apps/sample-api/tests/test_api.py

## Blockers

- Python 3.13 vs pinned pydantic-core: Building wheels failed for pinned versions. Resolved by unpinning/upgrading to compatible releases.
- PEP 668 "externally managed" environment: Could not install globally. Resolved by using a project-local virtual environment.

## Next Steps

- Structured logging with correlation IDs:
  - Add request ID middleware; propagate X-Request-ID; include in logs.
  - Choose logging stack (std logging + uvicorn config) and JSON output.
- Observability:
  - Add OpenTelemetry instrumentation (traces + metrics); integrate with existing Prometheus metrics.
- Testing & Quality:
  - Add pytest-cov; enforce ≥ 80 % coverage in CI; expand tests for error/edge paths.
  - Add pre-commit with black, isort, flake8; add .flake8 with project max-line-length and exclusions as needed.
- Dependencies:
  - Re-pin via constraints/lock (requirements.txt or pip-tools) compatible with CI Python versions; add matrix if needed.
- Packaging/Runtime:
  - Review and optimize Dockerfile (multi-stage, non-root user, distroless/ubi minimal).
  - Ensure health/metrics endpoints are exposed/configured in Helm chart (task-4).
- Documentation:
  - Update README/service docs for local run, testing, metrics, health, and env vars.

## Notes

- Current endpoints:
  - / → redirects to /docs [root.router](apps/sample-api/app/routes/root.py)
  - /docs, /redoc, /openapi.json → API documentation
  - /health/live, /health/ready, /health/startup → health probes [health](apps/sample-api/app/routes/health.py)
  - /api/version, /api/info → app/version info [info](apps/sample-api/app/routes/info.py)
  - /metrics → Prometheus metrics [app.main](apps/sample-api/app/main.py)
  - /demo/slow, /demo/error, /demo/cpu, /demo/memory → feature-flag simulation [demo](apps/sample-api/app/routes/demo.py)
- CI status: pytest passing (7 passed). Lint/formatting aligned (flake8, black, isort) to prevent CI failures.
