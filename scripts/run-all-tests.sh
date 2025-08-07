#!/bin/bash
set -euo pipefail

echo "🧪 Running complete test suite..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test categories
declare -A test_suites=(
    ["infrastructure"]="tests/infrastructure"
    ["application"]="tests/application"
    ["gitops"]="tests/gitops"
    ["rollouts"]="tests/rollouts"
    ["performance"]="tests/performance"
    ["observability"]="tests/observability"
    ["chaos"]="tests/chaos"
    ["integration"]="tests/integration"
)

# Results tracking
declare -A results

# Run each test suite
for suite in "${!test_suites[@]}"; do
    echo -e "\n${YELLOW}Running $suite tests...${NC}"

    if pytest "${test_suites[$suite]}" -v --tb=short; then
        results[$suite]="✅ PASSED"
        echo -e "${GREEN}$suite tests passed!${NC}"
    else
        results[$suite]="❌ FAILED"
        echo -e "${RED}$suite tests failed!${NC}"
    fi
done

# Generate HTML report
echo -e "\n📊 Generating test report..."
pytest --html=test-report.html --self-contained-html

# Summary
echo -e "\n${YELLOW}=== Test Results Summary ===${NC}"
for suite in "${!results[@]}"; do
    echo "$suite: ${results[$suite]}"
done

# Check if any failed
failed=false
for result in "${results[@]}"; do
    if [[ $result == *"FAILED"* ]]; then
        failed=true
        break
    fi
done

if $failed; then
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
fi