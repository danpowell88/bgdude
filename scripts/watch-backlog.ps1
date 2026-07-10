<#
Watch the backlog without interrupting any other work.

Maintains a read-only mirror clone of main in its OWN folder (default: ..\bgdude-watch,
a sibling of this repo) and refreshes it on a loop. Because it never touches this working
tree or any agent worktree, implementer/reviewer loops can keep working while you watch.
The mirror is hard-reset to origin/main on every change — never edit files in it.

Usage:
  pwsh scripts/watch-backlog.ps1                  # refresh every 60s, print backlog on change
  pwsh scripts/watch-backlog.ps1 -IntervalSec 30
  pwsh scripts/watch-backlog.ps1 -Browser         # also open the Backlog.md web UI on the mirror
  pwsh scripts/watch-backlog.ps1 -WatchDir D:\tmp\bgdude-watch

Ctrl+C to stop. Requires git + the backlog CLI on PATH.
#>
param(
    [string]$WatchDir,
    [string]$RemoteUrl = 'https://github.com/danpowell88/bgdude.git',
    [int]$IntervalSec = 60,
    [switch]$Browser
)

$ErrorActionPreference = 'Stop'

if (-not $WatchDir) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $WatchDir = Join-Path (Split-Path -Parent $repoRoot) 'bgdude-watch'
}

if (-not (Test-Path (Join-Path $WatchDir '.git'))) {
    Write-Host "Cloning read-only mirror into $WatchDir ..."
    git clone --branch main $RemoteUrl $WatchDir | Out-Host
}

if ($Browser) {
    # The Backlog.md web UI reads the mirror's files per request, so each pull below
    # shows up on a browser refresh.
    Start-Process pwsh -WorkingDirectory $WatchDir -ArgumentList '-NoProfile', '-Command', 'backlog browser'
}

# Runs in $WatchDir (Push-Location below), so the backlog CLI reads the mirror, not this repo.
function Show-Backlog {
    foreach ($status in 'In Progress', 'Review', 'Blocked') {
        Write-Host "`n--- $status ---" -ForegroundColor Cyan
        backlog task list -s $status --plain 2>$null | Out-Host
    }
    Write-Host "`n--- To Do (next 10 by ordinal) ---" -ForegroundColor Cyan
    backlog task list -s 'To Do' --limit 10 --plain 2>$null | Out-Host
}

Push-Location $WatchDir
try {
    git fetch --quiet origin main
    git reset --hard --quiet origin/main
    Write-Host "Watching $RemoteUrl (main) in $WatchDir — refresh every ${IntervalSec}s, Ctrl+C to stop."
    Show-Backlog
    while ($true) {
        Start-Sleep -Seconds $IntervalSec
        git fetch --quiet origin main
        $local = git rev-parse HEAD
        $remote = git rev-parse origin/main
        if ($local -ne $remote) {
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] main moved:" -ForegroundColor Yellow
            git log --oneline "$local..$remote" | Out-Host
            git reset --hard --quiet origin/main
            Show-Backlog
        }
    }
}
finally {
    Pop-Location
}
