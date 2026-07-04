# Regenerate the documentation media (screenshots + walkthrough video) for doc/index.html.
#
#   powershell -File tools/gen_docs.ps1                # screenshots only
#   powershell -File tools/gen_docs.ps1 -Video         # also record the walkthrough
#   powershell -File tools/gen_docs.ps1 -Device emulator-5554
#
# Requires: a running Android device/emulator, Flutter on PATH (or edit $FlutterBin),
# and adb (from the Android SDK platform-tools). The app is driven in DEV MODE so every
# screen is populated with simulated data — no pump hardware needed.

param(
  [string]$Device = "",
  [switch]$Video,
  [string]$FlutterBin = "C:\flutter\flutter\bin",
  [int]$VideoSeconds = 120
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

# --- Screenshots ---
Write-Host "Capturing screenshots -> doc/screenshots/ ..."
flutter drive `
  --driver=test_driver/screenshot_driver.dart `
  --target=integration_test/screenshots_test.dart `
  -d $Device
Write-Host "Screenshots done." -ForegroundColor Green

# --- Walkthrough video (optional) ---
if ($Video) {
  $adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
  if (-not $adb) { $adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe" }
  if (-not (Test-Path $adb)) { throw "adb not found; install platform-tools or add adb to PATH." }

  New-Item -ItemType Directory -Force "doc/media" | Out-Null
  Write-Host "Recording walkthrough (~$VideoSeconds s) ..."

  # Record in the background, then drive the app; screenrecord stops at the time limit.
  $rec = Start-Job -ScriptBlock {
    param($adb, $dev, $secs)
    & $adb -s $dev shell screenrecord --time-limit $secs --bit-rate 6000000 /sdcard/bgdude_walkthrough.mp4
  } -ArgumentList $adb, $Device, $VideoSeconds

  Start-Sleep -Seconds 2
  flutter test integration_test/walkthrough_test.dart -d $Device

  # Give screenrecord a moment to flush, then stop it and pull the file.
  & $adb -s $Device shell "pkill -INT screenrecord" 2>$null
  Start-Sleep -Seconds 3
  Wait-Job $rec -Timeout 20 | Out-Null
  Remove-Job $rec -Force -ErrorAction SilentlyContinue
  & $adb -s $Device pull /sdcard/bgdude_walkthrough.mp4 doc/media/walkthrough.mp4
  Write-Host "Walkthrough video -> doc/media/walkthrough.mp4" -ForegroundColor Green

  # Optional GIF if ffmpeg is available.
  $ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
  if ($ffmpeg) {
    & $ffmpeg -y -i doc/media/walkthrough.mp4 -vf "fps=10,scale=360:-1:flags=lanczos" doc/media/walkthrough.gif
    Write-Host "Walkthrough GIF -> doc/media/walkthrough.gif" -ForegroundColor Green
  } else {
    Write-Host "(ffmpeg not found — skipped GIF; the mp4 embeds fine in the docs.)"
  }
}

Write-Host "Open doc/index.html to view the docs." -ForegroundColor Cyan
