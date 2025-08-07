#!/bin/bash
set -euo pipefail

echo "🧪 Setting up test environment..."

# Install Python test dependencies
pip install -r tests/requirements.txt

# Install k6 for load testing
if ! command -v k6 &> /dev/null; then
    echo "Installing k6..."
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
    echo "deb https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
    sudo apt-get update
    sudo apt-get install k6
fi

# Install httpie for API testing
pip install httpie

# Install Robot Framework for E2E tests
pip install robotframework robotframework-requests robotframework-kubelibrary

# Install Chaos Mesh
echo "Installing Chaos Mesh..."
curl -sSL https://mirrors.chaos-mesh.org/v2.5.1/install.sh | bash -s -- --local kind

echo "✅ Test environment setup complete!"