#!/bin/bash
set -euo pipefail

ENDPOINT=${1:-http://app.local}
EXPECTED_VERSION=${2:-}

echo "🏥 Performing health checks on ${ENDPOINT}"

# Basic health check
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${ENDPOINT}/health/ready)
if [ $HTTP_CODE -eq 200 ]; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed (HTTP ${HTTP_CODE})"
    exit 1
fi

# Version check
if [ -n "$EXPECTED_VERSION" ]; then
    ACTUAL_VERSION=$(curl -s ${ENDPOINT}/api/version | jq -r .version)
    if [ "$ACTUAL_VERSION" == "$EXPECTED_VERSION" ]; then
        echo "✅ Version check passed (${ACTUAL_VERSION})"
    else
        echo "❌ Version mismatch (expected: ${EXPECTED_VERSION}, actual: ${ACTUAL_VERSION})"
        exit 1
    fi
fi

# Metrics check
METRICS=$(curl -s ${ENDPOINT}/metrics | grep -c "^http_requests_total")
if [ $METRICS -gt 0 ]; then
    echo "✅ Metrics endpoint working"
else
    echo "❌ Metrics not available"
    exit 1
fi

echo "✅ All health checks passed!"