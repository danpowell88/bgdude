# Regenerate the Garmin screenshots used in the user guide by building each Connect IQ
# product, running it in the Connect IQ simulator, and capturing + cropping the device.
#
# Unlike the Flutter app screenshots (integration_test/screenshots_test.dart), the watch
# products render in Garmin's simulator, so they need this separate script. It:
#   1. builds widget / watch face / data field for a target device,
#   2. temporarily seeds a sample reading (restored afterwards — the committed source
#      shows real data only from the phone),
#   3. runs each in the simulator and captures the device to a cropped PNG.
#
# Requirements: the Connect IQ SDK (monkeyc/monkeydo/simulator) and an installed device.
# Windows only (the CIQ simulator + System.Drawing capture are Windows).
#
#   powershell -ExecutionPolicy Bypass -File garmin/tools/screenshots.ps1 `
#       [-Device fenix847mm] [-OutDir ..\doc\screenshots]
param(
    [string]$Device = "fenix847mm",
    [string]$OutDir = "$PSScriptRoot\..\..\doc\screenshots",
    [string]$Sdk    = ""
)
$ErrorActionPreference = "Stop"
$garmin = Resolve-Path "$PSScriptRoot\.."
$tmp    = Join-Path $env:TEMP "bgdude-garmin-shots"
New-Item -ItemType Directory -Force -Path $tmp, $OutDir | Out-Null

# --- Locate the SDK -------------------------------------------------------------------
if (-not $Sdk) {
    $cfg = "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg"
    if (Test-Path $cfg) { $Sdk = (Get-Content $cfg -Raw).Trim() }
    if (-not $Sdk) {
        $Sdk = (Get-ChildItem "$env:APPDATA\Garmin\ConnectIQ\Sdks" -Directory |
                Sort-Object Name | Select-Object -Last 1).FullName
    }
}
$monkeyc   = Join-Path $Sdk "bin\monkeyc.bat"
$monkeydo  = Join-Path $Sdk "bin\monkeydo.bat"
$simulator = Join-Path $Sdk "bin\simulator.exe"
if (-not (Test-Path $monkeyc)) { throw "monkeyc not found under $Sdk" }
Write-Host "SDK: $Sdk"

# --- Developer key --------------------------------------------------------------------
$key = Join-Path $tmp "developer_key.der"
if (-not (Test-Path $key)) {
    $pem = Join-Path $tmp "developer_key.pem"
    & openssl genrsa -out $pem 4096 2>$null
    & openssl pkcs8 -topk8 -inform PEM -outform DER -in $pem -out $key -nocrypt 2>$null
}

# --- Products -------------------------------------------------------------------------
$products = @(
    @{ name="widget";    jungle="monkey.jungle";    app="source\BgDudeApp.mc";            out="23-garmin-widget.png" },
    @{ name="watchface"; jungle="watchface.jungle";  app="source-watchface\BgDudeWatchFaceApp.mc"; out="24-garmin-watchface.png" },
    @{ name="datafield"; jungle="datafield.jungle";  app="source-datafield\BgDudeDataFieldApp.mc";  out="25-garmin-datafield.png" }
)
$seed = '        BgData.save({ "bg" => 131, "trend" => "fortyFiveUp", "delta" => 11, "ageSec" => 120, "iob" => 1.4, "unit" => "mmol", "battery" => 68, "reservoir" => 142.0 });'
$manifests = "manifest.xml","manifest-watchface.xml","manifest-datafield.xml"
$backups = @{}

# --- Screen-capture helper (CopyFromScreen handles the simulator's GL surface) ---------
Add-Type -ReferencedAssemblies System.Drawing,System.Windows.Forms -TypeDefinition @"
using System;using System.Drawing;using System.Runtime.InteropServices;
public class GShot {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  public struct RECT { public int L,T,R,B; }
  public static void Shot(IntPtr h, string path, int cx, int cy, int cw, int ch){
    ShowWindow(h,9); SetForegroundWindow(h); System.Threading.Thread.Sleep(900);
    RECT r; GetWindowRect(h, out r);
    using(var full=new Bitmap(r.R-r.L, r.B-r.T)){
      using(var g=Graphics.FromImage(full)){ g.CopyFromScreen(r.L,r.T,0,0,full.Size); }
      var rect=new Rectangle(cx,cy,cw,ch);
      using(var crop=full.Clone(rect, full.PixelFormat)){ crop.Save(path); }
    }
  }
}
"@

function Get-SimWindow {
    for ($i=0; $i -lt 30; $i++) {
        $p = Get-Process | Where-Object { $_.MainWindowTitle -match "CIQ Simulator" } | Select-Object -First 1
        if ($p) { return $p }
        Start-Sleep -Milliseconds 500
    }
    throw "CIQ Simulator window not found"
}

try {
    Push-Location $garmin
    # Back up + temporarily seed the apps and enable the target device.
    foreach ($p in $products) {
        $backups[$p.app] = [IO.File]::ReadAllText((Resolve-Path $p.app))
        $s = $backups[$p.app] -replace '(function onStart\(state as Dictionary or Null\) as Void \{\r?\n)', "`$1$seed`n"
        [IO.File]::WriteAllText((Resolve-Path $p.app), $s)
    }
    foreach ($m in $manifests) {
        $backups[$m] = [IO.File]::ReadAllText((Resolve-Path $m))
        if ($backups[$m] -notmatch [regex]::Escape($Device)) {
            $s = $backups[$m] -replace '(<iq:products>\r?\n?)', "`$1            <iq:product id=`"$Device`"/>`n"
            [IO.File]::WriteAllText((Resolve-Path $m), $s)
        }
    }

    # Build each product.
    foreach ($p in $products) {
        $prg = Join-Path $tmp "$($p.name).prg"
        & $monkeyc -f $p.jungle -d $Device -o $prg -y $key
        if (-not (Test-Path $prg)) { throw "build failed: $($p.name)" }
        Write-Host "built $($p.name)"
    }

    # Launch simulator once, then side-load + capture each product.
    Start-Process -FilePath $simulator | Out-Null
    Start-Sleep -Seconds 6
    $win = (Get-SimWindow).MainWindowHandle
    foreach ($p in $products) {
        $prg = Join-Path $tmp "$($p.name).prg"
        Start-Process -FilePath $monkeydo -ArgumentList "`"$prg`"","$Device" -WindowStyle Hidden | Out-Null
        Start-Sleep -Seconds 11
        $win = (Get-SimWindow).MainWindowHandle
        [GShot]::Shot($win, (Join-Path $OutDir $p.out), 95, 56, 542, 900)
        Write-Host "captured $($p.out)"
    }
}
finally {
    # Always restore the committed source / manifests (byte-accurate, no EOL translation).
    foreach ($k in $backups.Keys) { [IO.File]::WriteAllText((Resolve-Path $k), $backups[$k]) }
    Get-Process | Where-Object { $_.MainWindowTitle -match "CIQ Simulator" -or $_.ProcessName -match "simulator" } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Pop-Location
    Write-Host "restored source; screenshots in $OutDir"
}
