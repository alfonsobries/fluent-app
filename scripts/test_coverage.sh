#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift test --enable-code-coverage

BIN_PATH="$(find .build -path '*/debug/FluentAppPackageTests.xctest/Contents/MacOS/FluentAppPackageTests' -print -quit)"
PROFILE_PATH="$(find .build -path '*/debug/codecov/default.profdata' -print -quit)"

if [[ -z "$BIN_PATH" || ! -f "$BIN_PATH" ]]; then
  echo "Coverage binary not found."
  exit 127
fi

if [[ -z "$PROFILE_PATH" || ! -f "$PROFILE_PATH" ]]; then
  echo "Coverage profile not found."
  exit 127
fi

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
