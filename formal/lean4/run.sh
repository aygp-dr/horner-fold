#!/usr/bin/env bash
# Build and run Lean4 Horner proofs
set -euo pipefail
cd "$(dirname "$0")"
echo "=== Lean4: Building and verifying Horner proofs ==="
lake build
echo "--- Running executable ---"
lake exec horner
