# run-agent.ps1 — start a task-pipeline agent (decisions 10 + 12 + 13; see doc/process.html).
#
# Wraps `claude` (Claude Code CLI) or `qwen` (qwen code CLI) with the right loop prompt,
# model tier, and working directory, so "work on the issue queue" is one command:
#
#   pwsh scripts/run-agent.ps1                                # one implementer run (claude, sonnet)
#   pwsh scripts/run-agent.ps1 -Role reviewer                 # one reviewer run (claude, opus)
#   pwsh scripts/run-agent.ps1 -Agent qwen                    # implementer via qwen code
#   pwsh scripts/run-agent.ps1 -Loop -IntervalMinutes 45      # run forever, 45 min between runs
#
# Each iteration is a fresh agent process that follows loops/<role>.md end-to-end (pick ->
# claim -> implement -> PR -> hand off). Coordination happens through GitHub issue labels
# (`status:*`) and signed claiming comments, so multiple instances / machines are safe to
# run concurrently.

param(
  [ValidateSet('implementer', 'reviewer', 'groomer')]
  [string]$Role = 'implementer',

  [ValidateSet('claude', 'qwen')]
  [string]$Agent = 'claude',

  # Model override. Defaults per role: implementer -> sonnet (cheap tier),
  # reviewer/groomer -> opus (expensive tier). Ignored for qwen (uses its own config).
  [string]$Model,

  [switch]$Loop,
  [int]$IntervalMinutes = 30
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$promptFile = Join-Path $repo "loops\$Role.md"
if (-not (Test-Path $promptFile)) { throw "Loop prompt not found: $promptFile" }
if (-not $Model) { $Model = if ($Role -eq 'implementer') { 'sonnet' } else { 'opus' } }

$goal = "Read CLAUDE.md, then follow the instructions in loops/$Role.md for one full iteration, end to end."

do {
  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Write-Host "[$stamp] run-agent: role=$Role agent=$Agent$(if ($Agent -eq 'claude') { " model=$Model" })" -ForegroundColor Cyan

  Push-Location $repo
  try {
    if ($Agent -eq 'claude') {
      # --permission-mode acceptEdits: file edits + allowlisted commands run unattended;
      # anything outside that still stops rather than doing something destructive.
      claude -p $goal --model $Model --permission-mode acceptEdits
    }
    else {
      # qwen code follows the same repo conventions; it signs with its own agent id.
      qwen --yolo -p "$goal Sign all issue comments, implemented-by tags and git commits as qwen-code."
    }
    if ($LASTEXITCODE -ne 0) { Write-Warning "agent exited with code $LASTEXITCODE" }
  }
  finally {
    Pop-Location
  }

  if ($Loop) {
    Write-Host "run-agent: sleeping $IntervalMinutes min (Ctrl+C to stop)" -ForegroundColor DarkGray
    Start-Sleep -Seconds ($IntervalMinutes * 60)
  }
} while ($Loop)
