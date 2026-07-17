# Project conventions for Claude

## Always keep the user guide current
On any user-visible change — a feature, page, panel, icon, notification category, mode,
report, or setting — update `doc/user-guide.html` in the **same change** so it never drifts
from the app, and keep `doc/index.html` (marketing/overview) roughly in step. The user guide
is the source of truth for "how to use it". Full details + the screenshot-regeneration
command: the **`user-guide-sync`** skill (`.claude/skills/user-guide-sync/`).

## Agent skills
Reusable, on-demand skills live in `.claude/skills/` and load automatically when relevant —
see `.claude/skills/README.md`. Several sections below are one-line summaries that point into
a skill for the full detail; keep both in sync as the code evolves.

- **Bespoke (this repo):** `bgdude-issues` (the issue workflow), `verify-build` (the
  CI-equivalent pipeline), `coverage-ratchet`, `bug-sweep`, `drift-sqlcipher`,
  `pumpx2-native-bridge` (read-only pump charter), `integration-test-harness`,
  `user-guide-sync`, `android-release`.
- **Vendored (general tooling):** `github` (gh CLI), the official `flutter-*` set, `android-cli`.

## GitHub Issues (task tracking — the single planning source)
All planning lives in **GitHub Issues** on `danpowell88/bgdude` (CLI: `gh`). Issues are the
unit of execution; **status is a `status:*` label** (exactly one per open issue) and a
**closed issue is Done** — closing is Summer's act. Milestones carry the phasing; project #2
is the backlog board; decisions outliving an issue live in `doc/decisions/decision-<n>.md`.
**PRs never auto-close issues** — reference `Refs #<n>`, never `Closes #<n>` (that would
bypass the human gate).

The full operational workflow — the status pipeline, the gh cheat-sheet, ordinals and
issue-body structure, the claim/finish/blocked steps, and the comment tags (`implemented-by:`
/ `friction:`) — is the **`bgdude-issues`** skill (`.claude/skills/bgdude-issues/`).

## Agent fleet (tooling; pipeline change PROPOSED, not in effect)
A tiered agent fleet — implementer / escalation / reviewer / groomer / reaper role loops,
driven by `scripts/run-agent.ps1` across harnesses (claude / qwen / copilot) — is documented
in `loops/README.md` (`AGENTS.md` points non-Claude harnesses at these conventions). Working
`gh` for the board needs the Projects scope: `gh auth refresh -s project` (one-time per
machine). **Note:** decision-15 proposes making project-board columns the canonical pipeline
stage (with labels demoted to routing flags); that contradicts the standing labels-canonical
convention above and is **not in effect until Summer approves it** — until then the
`bgdude-issues` skill remains authoritative.

## Git
**Concurrent sessions isolate via worktrees + branches — ALL work, no exceptions.** When more
than one session/agent writes to this repo at once each works in its **own git worktree on its own short-lived
branch off `main`** — this is what prevents two sessions racing on one working tree (the "file
modified since read" / manually-scoped-commit problem). 

**Task work ships as a GitHub PR and reaches `main` only via a reviewed, CI-green PR merge
(decision-10).** Do NOT push task work straight to `main`. Concretely:
- One branch per issue with a descriptive name of hte issue number and fix,

## Verify the build after EVERY task (must match CI — CI is the source of truth)
The GitHub Actions workflow (`.github/workflows/ci.yml`) is what decides if `main` is
green, and **it must never be left red**. `flutter analyze` + `flutter test` passing is
**not sufficient** — CI also generates code and builds the APK, so a change can be
"green locally" yet break CI. After finishing any task (and before committing), run the
**same pipeline CI runs, in this order**, and only commit when it all passes — the exact
steps are in the `verify-build` skill (`.claude/skills/verify-build/`).

If any step fails, fix it before committing — do not push a change that would turn CI
red. If CI is already red on `main`, treat getting it green as part of the current task.
Native code is buildable/testable here (JDK + Android SDK present); verify pumpx2 APIs via
`javap` on the cached jar before writing.

## Fixing a bug? Sweep the whole surface — don't just patch the reported site
The most common defect is a fix that **protects its literal target but leaves the
symmetric/adjacent path unguarded**. Before calling a fix done, sweep four axes: **sibling
call sites** (grep the same construct, patch every occurrence), **both branches / every
side-effect** of the action, **a test that actually fails if the fix is reverted** (not
`returnsNormally`), and **concurrency/security nuance** (visibility ≠ atomicity). Full
guidance + the recurring examples: the **`bug-sweep`** skill.

## Emulator (integration) tests for every feature
Every user-facing screen/flow gets on-device coverage under `integration_test/` (shared
demo-mode helpers in `integration_test/harness.dart`). Add or extend a test whenever you add
or change a screen, panel, mode, report, or setting. How to run a single file on an emulator
+ harness usage + the `flutter drive` caveat: the **`integration-test-harness`** skill.
