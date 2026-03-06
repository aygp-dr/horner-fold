#!/usr/bin/env bash
# Run Alloy model checker on Horner specification
set -euo pipefail
cd "$(dirname "$0")"
echo "=== Alloy: Checking Horner roundtrip properties ==="
alloy exec -t text -o - horner.als
