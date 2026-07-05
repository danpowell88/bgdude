# Build the bgdude Connect IQ unit tests and run them in the simulator.
#
# Prereqs (see ../README.md):
#   * Connect IQ SDK installed, with monkeyc + monkeydo + connectiq on PATH.
#   * A developer key at garmin/developer_key.der (openssl steps in README).
#
# Usage (from garmin/):
#   powershell -File tools/run_tests.ps1 [-Device fenix7]
param(
    [string]$Device = "fenix7",
    [string]$Key = "developer_key.der"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot   # garmin/
Set-Location $root

if (-not (Get-Command monkeyc -ErrorAction SilentlyContinue)) {
    throw "monkeyc not on PATH — install the Connect IQ SDK and add its bin/ to PATH."
}
if (-not (Test-Path $Key)) {
    throw "Developer key '$Key' not found — generate one (see README section 2)."
}

New-Item -ItemType Directory -Force -Path bin | Out-Null

Write-Host "Building unit tests for $Device..."
& monkeyc -f test.jungle -d $Device --unit-test -o bin/test.prg -y $Key -w
if ($LASTEXITCODE -ne 0) { throw "monkeyc build failed ($LASTEXITCODE)" }

# The simulator must be running for monkeydo. Start it if it isn't already.
if (-not (Get-Process -Name "connectiq","simulator" -ErrorAction SilentlyContinue)) {
    Write-Host "Starting Connect IQ simulator..."
    Start-Process connectiq
    Start-Sleep -Seconds 6
}

Write-Host "Running tests (-t) in the simulator..."
& monkeydo bin/test.prg $Device -t
exit $LASTEXITCODE
