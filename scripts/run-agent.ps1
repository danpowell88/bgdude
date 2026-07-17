# run-agent.ps1 — start a task-pipeline agent (decisions 10 + 12 + 13 + 15).
#
# Wraps `claude` (Claude Code CLI), `qwen` (qwen-code CLI) or `copilot` (GitHub Copilot
# CLI) with the right loop prompt, model tier, and working directory, so "work on the
# issue queue" is one command:
#
#   pwsh scripts/run-agent.ps1                                 # interactive picker
#   pwsh scripts/run-agent.ps1 -Role implementer -Agent qwen   # one qwen implementer run
#   pwsh scripts/run-agent.ps1 -Role implementer -Model haiku  # cheap Claude implementer
#   pwsh scripts/run-agent.ps1 -Role escalation                # sonnet rescue run
#   pwsh scripts/run-agent.ps1 -Role reviewer                  # one opus review run
#   pwsh scripts/run-agent.ps1 -Role reaper                    # release stale claims (no LLM)
#   pwsh scripts/run-agent.ps1 -Role implementer -Loop -IntervalMinutes 45
#
# Each iteration is a fresh agent process that follows loops/<role>.md end-to-end.
# Coordination happens through the project board (#2 `Status` column, decision-15) and
# signed claiming comments, so multiple instances / machines are safe to run concurrently.
# The queue state lives on GitHub — nothing is shared between machines except the repo.
#
# Per-machine setup: `gh auth login` + `gh auth refresh -s project` (Projects v2 scope),
# `claude login` (subscription — no API credits), and qwen/copilot CLIs where used.

param(
  [ValidateSet('implementer', 'escalation', 'reviewer', 'groomer', 'reaper')]
  [string]$Role,

  [ValidateSet('claude', 'qwen', 'copilot')]
  [string]$Agent,

  # Model override (claude only; qwen/copilot use their own config). Defaults per role:
  # implementer -> sonnet (haiku is the cheap option), escalation -> sonnet,
  # reviewer/groomer -> opus.
  [string]$Model,

  [switch]$Loop,
  [int]$IntervalMinutes = 30,

  # Hard bound on a runaway agentic run (claude --max-turns). 0 = role default
  # (implementer/escalation 40, reviewer/groomer 25).
  [int]$MaxTurns = 0,

  # claude --permission-mode. `acceptEdits` is the safe default; switch to `auto`
  # (classifier-backed) per machine once validated there.
  [string]$PermissionMode = 'acceptEdits',

  # Skip an iteration when the shared account's remaining GitHub quota (core or
  # GraphQL) is below this — better to idle than die mid-claim.
  [int]$RateLimitFloor = 200,

  # Reaper: release Doing/Reviewing items with no server-side activity for this long.
  [int]$StaleMinutes = 45,

  # Suppress all prompts even when parameters are missing (schtasks/cron safety net;
  # missing values fall back to role defaults).
  [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$repoDir = Split-Path $PSScriptRoot -Parent
$script:ProjectOwner = 'danpowell88'
$script:ProjectNumber = '2'
$script:Repo = 'danpowell88/bgdude'

# ---------------------------------------------------------------------------
# GitHub plumbing: rate-limit-aware gh wrapper + quota pre-flight
# ---------------------------------------------------------------------------

function Invoke-Gh {
  # Run gh with graceful handling of 403/429 secondary/abuse limits: honor
  # Retry-After when present, else exponential backoff with jitter. Non-rate-limit
  # failures throw immediately.
  param(
    [Parameter(Mandatory)][string[]]$GhArgs,
    [int]$MaxTries = 5
  )
  $delay = 2
  for ($try = 1; $try -le $MaxTries; $try++) {
    $out = & gh @GhArgs 2>&1
    if ($LASTEXITCODE -eq 0) { return ($out | Out-String).TrimEnd() }
    $text = ($out | Out-String)
    if ($text -match 'HTTP 403|HTTP 429|rate limit|secondary rate|abuse detection') {
      $wait = $delay
      if ($text -match 'Retry-After:?\s*(\d+)') { $wait = [int]$Matches[1] }
      $wait += Get-Random -Minimum 0 -Maximum 4
      Write-Warning "gh rate-limited (attempt $try/$MaxTries); waiting ${wait}s"
      Start-Sleep -Seconds $wait
      $delay = [Math]::Min($delay * 2, 64)
      continue
    }
    throw "gh $($GhArgs -join ' ') failed: $text"
  }
  throw "gh $($GhArgs -join ' ') still rate-limited after $MaxTries attempts"
}

function Test-RateBudget {
  # Pre-flight: skip the iteration when the shared account is close to exhaustion.
  # Board reads/writes draw on GraphQL; issue/PR calls draw on core — check both.
  try {
    $rl = (& gh api rate_limit 2>$null | ConvertFrom-Json).resources
    if ($LASTEXITCODE -ne 0 -or -not $rl) { return $true }  # can't check -> proceed
    $core = $rl.core.remaining
    $gql = $rl.graphql.remaining
    if ($core -lt $RateLimitFloor -or $gql -lt $RateLimitFloor) {
      $reset = [DateTimeOffset]::FromUnixTimeSeconds(
        [Math]::Max([long]$rl.core.reset, [long]$rl.graphql.reset)).LocalDateTime
      Write-Warning "GitHub quota low (core=$core graphql=$gql < $RateLimitFloor); idling until ~$reset"
      return $false
    }
  }
  catch { Write-Warning "rate_limit pre-flight failed ($_); proceeding" }
  return $true
}

# ---------------------------------------------------------------------------
# Project board plumbing (Projects v2; decision-15: board Status is canonical)
# ---------------------------------------------------------------------------

function Get-Board {
  # Resolve + cache the project/Status-field/option ids once per process.
  if ($script:Board) { return $script:Board }
  $projectId = (Invoke-Gh @('project', 'view', $script:ProjectNumber, '--owner', $script:ProjectOwner, '--format', 'json') |
    ConvertFrom-Json).id
  $fields = (Invoke-Gh @('project', 'field-list', $script:ProjectNumber, '--owner', $script:ProjectOwner, '--format', 'json') |
    ConvertFrom-Json).fields
  $status = $fields | Where-Object { $_.name -eq 'Status' }
  if (-not $status) { throw "board $($script:ProjectNumber) has no Status field" }
  $options = @{}
  foreach ($o in $status.options) { $options[$o.name] = $o.id }
  $script:Board = [pscustomobject]@{
    ProjectId     = $projectId
    StatusFieldId = $status.id
    StatusOptions = $options
  }
  return $script:Board
}

function Get-BoardItems {
  # One call returns the whole queue: item id, issue number, Status column, Ordinal.
  $raw = Invoke-Gh @('project', 'item-list', $script:ProjectNumber, '--owner', $script:ProjectOwner,
    '--format', 'json', '--limit', '500')
  return ($raw | ConvertFrom-Json).items
}

function Set-ItemStatus {
  param(
    [Parameter(Mandatory)][string]$ItemId,
    [Parameter(Mandatory)][string]$Status
  )
  $board = Get-Board
  $optionId = $board.StatusOptions[$Status]
  if (-not $optionId) { throw "unknown Status column '$Status'" }
  Invoke-Gh @('project', 'item-edit', '--project-id', $board.ProjectId, '--id', $ItemId,
    '--field-id', $board.StatusFieldId, '--single-select-option-id', $optionId) | Out-Null
}

# ---------------------------------------------------------------------------
# Reaper (no LLM): release claims whose agent went silent (crashed machine, killed
# process). Uses GitHub server timestamps only — immune to per-machine clock skew.
# ---------------------------------------------------------------------------

function Get-LastActivityUtc {
  param([Parameter(Mandatory)][int]$IssueNumber)
  $candidates = @()
  try {
    $comments = Invoke-Gh @('api', "repos/$($script:Repo)/issues/$IssueNumber/comments?per_page=100") |
      ConvertFrom-Json
    if ($comments) { $candidates += ($comments | ForEach-Object { [datetime]$_.created_at }) }
  }
  catch { Write-Warning "reaper: comments fetch failed for #${IssueNumber}: $_" }
  try {
    $commits = Invoke-Gh @('api', "repos/$($script:Repo)/commits?sha=issue-$IssueNumber&per_page=1") |
      ConvertFrom-Json
    if ($commits) { $candidates += [datetime]$commits[0].commit.committer.date }
  }
  catch { }  # branch may not exist yet — claim comment is then the only signal
  if (-not $candidates) { return $null }
  return ($candidates | Measure-Object -Maximum).Maximum.ToUniversalTime()
}

function Invoke-Reaper {
  if (-not (Test-RateBudget)) { return }
  $cutoff = (Get-Date).ToUniversalTime().AddMinutes(-$StaleMinutes)
  $release = @{ 'Doing' = 'To Do'; 'Reviewing' = 'Needs Review' }
  $items = Get-BoardItems | Where-Object { $_.status -in $release.Keys -and $_.content.number }
  if (-not $items) { Write-Host 'reaper: nothing in Doing/Reviewing'; return }
  foreach ($item in $items) {
    $n = $item.content.number
    $last = Get-LastActivityUtc -IssueNumber $n
    if ($null -eq $last) {
      # No comments and no branch: fall back to the issue's own server-side update time.
      $last = [datetime](Invoke-Gh @('api', "repos/$($script:Repo)/issues/$n", '-q', '.updated_at'))
      $last = $last.ToUniversalTime()
    }
    if ($last -ge $cutoff) {
      Write-Host ("reaper: #{0} active ({1:u}); leaving in {2}" -f $n, $last, $item.status)
      continue
    }
    $target = $release[$item.status]
    Write-Host ("reaper: releasing #{0} {1} -> {2} (quiet since {3:u})" -f $n, $item.status, $target, $last)
    Set-ItemStatus -ItemId $item.id -Status $target
    $body = ("reaper: released #{0} — no activity since {1:u} — returning to {2}. The claim " +
      'went silent (crashed machine or killed process); the branch/PR are untouched, the ' +
      'next agent resumes them.') -f $n, $last, $target
    Invoke-Gh @('issue', 'comment', "$n", '--repo', $script:Repo, '--body', $body) | Out-Null
  }
}

# ---------------------------------------------------------------------------
# Interactive picker (only when args are missing, the host is interactive, and
# -NonInteractive is not set — so schtasks/cron invocations never block)
# ---------------------------------------------------------------------------

function Select-Option {
  param(
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string[]]$Options,
    [Parameter(Mandatory)][string]$Default
  )
  Write-Host "`n$Title" -ForegroundColor Cyan
  for ($i = 0; $i -lt $Options.Count; $i++) {
    $marker = if ($Options[$i] -eq $Default) { ' (default)' } else { '' }
    Write-Host ("  {0}) {1}{2}" -f ($i + 1), $Options[$i], $marker)
  }
  while ($true) {
    $ans = Read-Host 'Choice'
    if ([string]::IsNullOrWhiteSpace($ans)) { return $Default }
    if ($ans -match '^\d+$' -and [int]$ans -ge 1 -and [int]$ans -le $Options.Count) {
      return $Options[[int]$ans - 1]
    }
    if ($Options -contains $ans) { return $ans }
    Write-Host 'Invalid choice, try again.' -ForegroundColor Yellow
  }
}

$interactive = (-not $NonInteractive) -and [Environment]::UserInteractive

if (-not $Role) {
  if ($interactive) {
    $Role = Select-Option -Title 'Role?' `
      -Options @('implementer', 'escalation', 'reviewer', 'groomer', 'reaper') -Default 'implementer'
  }
  else { $Role = 'implementer' }
}

if ($Role -ne 'reaper') {
  if (-not $Agent) {
    if ($interactive) {
      $Agent = Select-Option -Title 'Harness?' -Options @('claude', 'qwen', 'copilot') -Default 'claude'
    }
    else { $Agent = 'claude' }
  }
  if ($Agent -eq 'claude' -and -not $Model) {
    $default = switch ($Role) {
      'implementer' { 'sonnet' }
      'escalation' { 'sonnet' }
      default { 'opus' }
    }
    if ($interactive) {
      $Model = Select-Option -Title 'Model?' -Options @('haiku', 'sonnet', 'opus') -Default $default
    }
    else { $Model = $default }
  }
  if ($interactive -and -not $PSBoundParameters.ContainsKey('Loop')) {
    if ((Select-Option -Title 'Run once or loop?' -Options @('once', 'loop') -Default 'once') -eq 'loop') {
      $Loop = $true
      $ans = Read-Host "Interval minutes [default: $IntervalMinutes]"
      if ($ans -match '^\d+$') { $IntervalMinutes = [int]$ans }
    }
  }
}

if ($MaxTurns -le 0) {
  $MaxTurns = if ($Role -in @('implementer', 'escalation')) { 40 } else { 25 }
}

# Escalation and review runs need Claude-tier judgment — qwen/copilot stay on the
# implementer lane (decision-15).
if ($Role -in @('escalation', 'reviewer', 'groomer') -and $Agent -ne 'claude') {
  throw "role '$Role' requires -Agent claude (cheap harnesses only run the implementer loop)"
}

# ---------------------------------------------------------------------------
# One agent iteration
# ---------------------------------------------------------------------------

function Invoke-AgentOnce {
  $promptFile = Join-Path $repoDir (Join-Path 'loops' "$Role.md")
  if (-not (Test-Path $promptFile)) { throw "Loop prompt not found: $promptFile" }
  $goal = "Read CLAUDE.md, then follow the instructions in loops/$Role.md for one full iteration, end to end."

  if ($Agent -eq 'claude') {
    $claudeArgs = @('-p', $goal, '--model', $Model, '--permission-mode', $PermissionMode,
      '--max-turns', "$MaxTurns", '--output-format', 'json')
    if ($Role -eq 'reviewer') {
      # Machine-parseable verdicts (fail-closed: a malformed/missing verdict is a FAIL).
      $schema = @{
        type       = 'object'
        properties = @{
          verdicts = @{
            type  = 'array'
            items = @{
              type       = 'object'
              properties = @{
                issue   = @{ type = 'integer' }
                pr      = @{ type = 'integer' }
                verdict = @{ enum = @('PASS', 'FAIL', 'ESCALATE') }
                reasons = @{ type = 'array'; items = @{ type = 'string' } }
              }
              required   = @('issue', 'verdict', 'reasons')
            }
          }
        }
        required   = @('verdicts')
      } | ConvertTo-Json -Depth 8 -Compress
      $claudeArgs += @('--json-schema', $schema)
    }
    $raw = & claude @claudeArgs
    $exit = $LASTEXITCODE
    try {
      $envelope = ($raw -join "`n") | ConvertFrom-Json
      $cost = if ($envelope.total_cost_usd) { '{0:c4}' -f $envelope.total_cost_usd } else { 'n/a (subscription)' }
      Write-Host ("run-agent: session={0} cost={1} error={2}" -f $envelope.session_id, $cost, $envelope.is_error)
      if ($Role -eq 'reviewer' -and $envelope.structured_output) {
        foreach ($v in $envelope.structured_output.verdicts) {
          Write-Host ("run-agent: verdict #{0} PR#{1} -> {2}: {3}" -f $v.issue, $v.pr, $v.verdict, ($v.reasons -join '; '))
        }
      }
      if ($envelope.is_error) { Write-Warning 'agent run reported an error' }
    }
    catch { Write-Warning "could not parse claude JSON envelope (exit=$exit)" }
    if ($exit -ne 0) { Write-Warning "agent exited with code $exit" }
  }
  elseif ($Agent -eq 'qwen') {
    # qwen-code reads AGENTS.md (which points at CLAUDE.md); --yolo runs unattended.
    & qwen --yolo -p "$goal Sign all issue comments, implemented-by tags and git commits as qwen-code."
    if ($LASTEXITCODE -ne 0) { Write-Warning "qwen exited with code $LASTEXITCODE" }
  }
  else {
    # GitHub Copilot CLI; reads AGENTS.md. Flags current as of copilot CLI 1.x — if
    # `--allow-all-tools` is rejected, check `copilot help` for the renamed flag.
    & copilot -p "$goal Sign all issue comments, implemented-by tags and git commits as copilot-cli." --allow-all-tools
    if ($LASTEXITCODE -ne 0) { Write-Warning "copilot exited with code $LASTEXITCODE" }
  }
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

do {
  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Write-Host "[$stamp] run-agent: role=$Role$(if ($Role -ne 'reaper') { " agent=$Agent" })$(if ($Agent -eq 'claude' -and $Role -ne 'reaper') { " model=$Model" })" -ForegroundColor Cyan

  Push-Location $repoDir
  try {
    if ($Role -eq 'reaper') {
      Invoke-Reaper
    }
    elseif (Test-RateBudget) {
      Invoke-AgentOnce
    }
  }
  finally {
    Pop-Location
  }

  if ($Loop) {
    # ±0-20% jitter so several machines polling the shared account don't align.
    $jitter = (Get-Random -Minimum -20 -Maximum 21) / 100.0
    $sleepMinutes = [Math]::Max(1, $IntervalMinutes * (1 + $jitter))
    Write-Host ("run-agent: sleeping {0:n1} min (Ctrl+C to stop)" -f $sleepMinutes) -ForegroundColor DarkGray
    Start-Sleep -Seconds ([int]($sleepMinutes * 60))
  }
} while ($Loop)
