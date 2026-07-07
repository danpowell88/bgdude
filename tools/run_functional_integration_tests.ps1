# TASK-220: canonical list of the deterministic functional integration test files —
# used by local runs and CI so the file list lives in exactly one place. Excludes
# harness.dart (not a test file) and screenshots_test.dart/walkthrough_test.dart
# (those need `flutter drive`, not `flutter test`, per CLAUDE.md).
#
#   powershell -File tools/run_functional_integration_tests.ps1
#   powershell -File tools/run_functional_integration_tests.ps1 -Device emulator-5554
#
# Requires: a running Android device/emulator, Flutter on PATH (or edit $FlutterBin).

param(
  [string]$Device = "",
  [string]$FlutterBin = "C:\flutter\flutter\bin"
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
  "integration_test/features_flows_test.dart",
  "integration_test/features_protocol_explorer_test.dart",
  "integration_test/features_reports_test.dart",
  "integration_test/features_settings_test.dart",
  "integration_test/nutrition_ocr_accuracy_test.dart"
)

foreach ($f in $Files) {
  Write-Host "--- flutter test $f -d $Device ---"
  flutter test $f -d $Device
}
Write-Host "All functional integration tests passed." -ForegroundColor Green
