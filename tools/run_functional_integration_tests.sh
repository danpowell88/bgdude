#!/usr/bin/env bash
# TASK-220: canonical list of the deterministic functional integration test files —
# used by local runs and CI so the file list lives in exactly one place. Excludes
# harness.dart (not a test file) and screenshots_test.dart/walkthrough_test.dart
# (those need `flutter drive`, not `flutter test`, per CLAUDE.md).
#
#   tools/run_functional_integration_tests.sh                 # all files below
#   tools/run_functional_integration_tests.sh --device emulator-5554
#   tools/run_functional_integration_tests.sh --skip-network   # TASK-219: for CI —
#     nutrition_ocr_accuracy_test.dart needs real network + ~5 extra minutes, which
#     a nightly automated job shouldn't depend on; local runs default to including it.
#
# Requires: a running Android device/emulator and `flutter` on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE=""
SKIP_NETWORK=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2;;
    --skip-network) SKIP_NETWORK="1"; shift;;
    *) echo "unknown arg: $1"; exit 1;;
  esac
done

if [[ -z "$DEVICE" ]]; then
  DEVICE=$(flutter devices 2>/dev/null | grep -Eo '(emulator-[0-9]+)' | head -n1 || true)
  [[ -z "$DEVICE" ]] && { echo "No Android device found. Start an emulator or pass --device."; exit 1; }
fi
echo "Using device: $DEVICE"

# The single source of truth for "which integration_test files are deterministic
# functional tests" — keep in sync with run_functional_integration_tests.ps1.
FILES=(
  "integration_test/app_test.dart"
  "integration_test/chaos_navigation_test.dart"
  "integration_test/db_recovery_screen_test.dart"
  "integration_test/features_flows_test.dart"
  "integration_test/features_protocol_explorer_test.dart"
  "integration_test/features_reports_test.dart"
  "integration_test/features_settings_test.dart"
  "integration_test/nutrition_ocr_accuracy_test.dart"
)

# TASK-292: run every file regardless of an earlier one failing -- a plain `set -e`
# loop aborted the whole script on the FIRST failure, silently hiding pass/fail signal
# for every file scheduled after it (confirmed: a chaos_navigation_test.dart failure
# meant db_recovery_screen_test.dart, features_*_test.dart never ran at all).
PASSED=()
FAILED=()
for f in "${FILES[@]}"; do
  if [[ -n "$SKIP_NETWORK" && "$f" == *nutrition_ocr_accuracy_test.dart ]]; then
    echo "--- skipping $f (--skip-network) ---"
    continue
  fi
  echo "--- flutter test $f -d $DEVICE ---"
  if flutter test "$f" -d "$DEVICE"; then
    PASSED+=("$f")
  else
    FAILED+=("$f")
  fi
done

echo ""
echo "=== Summary ==="
for f in "${PASSED[@]:-}"; do
  [[ -n "$f" ]] && echo "  PASS  $f"
done
for f in "${FAILED[@]:-}"; do
  [[ -n "$f" ]] && echo "  FAIL  $f"
done

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "${#FAILED[@]} of $((${#PASSED[@]} + ${#FAILED[@]})) functional integration files failed."
  exit 1
fi
echo "All functional integration tests passed."
