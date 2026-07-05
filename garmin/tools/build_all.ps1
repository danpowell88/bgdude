# Build all four bgdude Connect IQ products (widget, watch face, data field) into bin/.
# Usage (from garmin/):  powershell -File tools/build_all.ps1 [-Device fenix7]
param(
    [string]$Device = "fenix7",
    [string]$Key = "developer_key.der"
)
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)   # garmin/
New-Item -ItemType Directory -Force -Path bin | Out-Null

$targets = @(
    @{ jungle = "monkey.jungle";     out = "bin/bgdude.prg" },            # widget + glance
    @{ jungle = "watchface.jungle";  out = "bin/bgdude-watchface.prg" },  # watch face
    @{ jungle = "datafield.jungle";  out = "bin/bgdude-datafield.prg" }   # data field
)
foreach ($t in $targets) {
    Write-Host "Building $($t.jungle) → $($t.out) for $Device"
    & monkeyc -f $t.jungle -d $Device -o $t.out -y $Key -w
    if ($LASTEXITCODE -ne 0) { throw "build failed for $($t.jungle)" }
}
Write-Host "Done. Sideload the .prg files onto the watch (GARMIN/Apps/)."
