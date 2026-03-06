#!/usr/bin/env bash
# Run TLC model checker on Horner specification
set -euo pipefail
cd "$(dirname "$0")"

TLA_JAR="${TLA_JAR:-$HOME/.local/lib/tla2tools.jar}"

if [ ! -f "$TLA_JAR" ]; then
    echo "Error: tla2tools.jar not found at $TLA_JAR"
    echo "Download from: https://github.com/tlaplus/tlaplus/releases"
    exit 1
fi

echo "=== TLA+: Model checking Horner specification ==="
java -cp "$TLA_JAR" tlc2.TLC Horner -config Horner.cfg -workers auto
