# TASK-220: canonical list of the deterministic functional integration test files —
# used by local runs and CI so the file list lives in exactly one place. Excludes
# harness.dart (not a test file) and screenshots_test.dart/walkthrough_test.dart
# (those need `flutter drive`, not `flutter test`, per CLAUDE.md).
#
#   powershell -File tools/run_functional_integration_tests.ps1
#   powershell -File tools/run_functional_integration_tests.ps1 -Device emulator-5554
#   powershell -File tools/run_functional_integration_tests.ps1 -SkipNetwork
#
# Requires: a running Android device/emulator, Flutter on PATH (or edit $FlutterBin).

param(
  [string]$Device = "",
  [string]$FlutterBin = "C:\flutter\flutter\bin",
  [switch]$SkipNetwork
)

$ErrorActionPreference = "Stop"
$env:Path = "$FlutterBin;" + $env:Path
Set-Location (Join-Path $PSScriptRoot "..")

if (-not $Device) {
  $line = (flutter devices 2>&1 | Select-String "emulator-\d+|android" | Select-Object -First 1)
  if ($line -match "(emulator-\d+|\S+)\s+•\s+(\S+)\s+•\s+android") { $Device = $Matches[2] }
  if (-not $Device) { throw "No Android device found. Start an emulator or pass -Device." }
}
Write-Host "Using device: $Device"

# The single source of truth for "which integration_test files are deterministic
# functional tests" — keep in sync with run_functional_integration_tests.sh.
$Files = @(
  "integration_test/app_test.dart",
  "integration_test/chaos_navigation_test.dart",
  "integration_test/db_recovery_screen_test.dart",
  "integration_test/features_flows_test.dart",
  "integration_test/features_protocol_explorer_test.dart",
  "integration_test/features_reports_test.dart",
  "integration_test/features_settings_test.dart",
  "integration_test/nutrition_ocr_accuracy_test.dart"
)

# TASK-292: run every file regardless of an earlier one failing -- silently stopping
# at the first failure (or, without explicit $LASTEXITCODE checks, PowerShell not
# stopping but still claiming "all passed" at the end) would hide pass/fail signal
# for every file after it.
$passed = @()
$failed = @()
foreach ($f in $Files) {
  if ($SkipNetwork -and $f -like "*nutrition_ocr_accuracy_test.dart") {
    Write-Host "--- skipping $f (-SkipNetwork) ---"
    continue
  }
  Write-Host "--- flutter test $f -d $Device ---"
  & flutter test $f -d $Device
  if ($LASTEXITCODE -eq 0) { $passed += $f } else { $failed += $f }
}

Write-Host ""
Write-Host "=== Summary ==="
foreach ($f in $passed) { Write-Host "  PASS  $f" -ForegroundColor Green }
foreach ($f in $failed) { Write-Host "  FAIL  $f" -ForegroundColor Red }

if ($failed.Count -gt 0) {
  Write-Host "$($failed.Count) of $($passed.Count + $failed.Count) functional integration files failed." -ForegroundColor Red
  exit 1
}
Write-Host "All functional integration tests passed." -ForegroundColor Green
