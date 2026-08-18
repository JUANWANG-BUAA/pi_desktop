#!/usr/bin/env bash
# Pi Desktop commit gate.
#
# docs/implementation-plan.md "提交规则" requires every commit to pass
# formatting, static analysis, tests (including the boundary scan in
# test/boundary/boundary_scan_test.dart) and `git diff --check`.
# Run this before every commit, or install it as a hook via
# tool/install_hooks.sh.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

echo "[1/4] dart format --set-exit-if-changed lib test"
dart format --output=none --set-exit-if-changed lib test

echo "[2/4] flutter analyze"
flutter analyze --no-pub

echo "[3/4] flutter test (includes the boundary scan)"
flutter test --no-pub

echo "[4/4] git diff --check"
git diff --check

echo "commit gate: all checks passed."
