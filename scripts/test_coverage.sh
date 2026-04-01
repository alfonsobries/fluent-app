#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift test --enable-code-coverage

BIN_PATH=".build/arm64-apple-macosx/debug/FluentAppPackageTests.xctest/Contents/MacOS/FluentAppPackageTests"
PROFILE_PATH=".build/arm64-apple-macosx/debug/codecov/default.profdata"

echo ""
echo "FluentCore coverage summary:"
xcrun llvm-cov report "$BIN_PATH" --instr-profile "$PROFILE_PATH" | rg 'Sources/FluentCore'

UNCOVERED_LINES="$(
  xcrun llvm-cov show "$BIN_PATH" --instr-profile "$PROFILE_PATH" $(find Sources/FluentCore -name '*.swift' -print) \
    | awk '/^[[:space:]]*[0-9]+\|[[:space:]]*0\|/ { print }'
)"

if [[ -n "$UNCOVERED_LINES" ]]; then
  echo ""
  echo "Uncovered executable lines detected in FluentCore:"
  echo "$UNCOVERED_LINES"
  exit 1
fi

echo ""
echo "FluentCore executable lines are fully covered."
