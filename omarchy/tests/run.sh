#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/tests/test_fluent.py"
node "$ROOT/tests/test_model.js"
python3 "$ROOT/tests/validate_plugin.py" "$ROOT"
echo "omarchy plugin checks passed"
