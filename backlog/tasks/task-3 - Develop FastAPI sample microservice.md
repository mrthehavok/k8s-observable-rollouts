---
id: task-3
title: "Develop FastAPI sample microservice"
status: "To Do"
depends_on: []
created: 2025-01-08
updated: 2025-01-08
---

## Description

Develop a sample FastAPI microservice that will serve as the target application for demonstrating progressive delivery with Argo Rollouts. The service should include health endpoints, metrics exposure, and feature flags to simulate different versions during rollouts.

## Acceptance Criteria

- [ ] FastAPI application with REST endpoints implemented
- [ ] Health check endpoints (/health, /ready) configured
- [ ] Prometheus metrics endpoint exposed
- [ ] Version endpoint returning current application version
- [ ] Feature flag endpoint to simulate different behaviors
- [ ] Unit tests with ≥80% coverage
- [ ] Dockerfile optimized for production use
- [ ] Configuration via environment variables
- [ ] Structured logging with correlation IDs

## Session History

<!-- Update as work progresses -->

## Decisions Made

<!-- Document key implementation decisions -->

## Files Modified

<!-- Track all file changes -->

## Blockers

<!-- Document any blockers encountered -->

## Next Steps

- Define API schema and endpoints
- Set up project structure following best practices
- Implement OpenTelemetry instrumentation
- Create comprehensive test suite

## Notes

- Use Python 3.11+ for better performance
- Implement async endpoints where appropriate
- Consider adding WebSocket endpoint for real-time features
- Include OpenAPI documentation
- Use Pydantic for data validation
