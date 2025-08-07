#!/bin/bash
VERSION=$(cat charts/sample-api/Chart.yaml | grep appVersion | awk '{print $2}' | tr -d '"')
git tag -a "v${VERSION}" -m "Release version ${VERSION}"
git push origin "v${VERSION}"