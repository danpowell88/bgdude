# decision-14 — Maximum-sensible static analysis: CodeQL thresholds tightened; fatal-infos, strict-inference, actionlint, Android Lint (baseline + warningsAsErrors), dependency review, Dependabot

- **Date:** 2026-07-11
- **Status:** accepted
- **Issue:** #331

## Context

Summer asked for CodeQL "as strict as possible where it makes sense", extended past
security, plus any other free quality gates for PRs. Findings:

- CodeQL already runs **`security-and-quality`** — the broadest built-in suite (it
  supersets `security-extended`; the only step further is `security-experimental`,
  rejected: low-precision/unreviewed queries produce FP noise that erodes trust in the
  gate). Dart remains unsupported by CodeQL — its strictness lives in the Dart analyzer.
- The merge-gate rule previously blocked only high+ security / error-level alerts.
- The Dart tree was already diagnostic-clean; `strict-inference` had exactly 6 findings;
  Android Lint had 0 errors / 44 warnings; actionlint was clean; 271/359 Dart files are
  not `dart format`-clean under Dart 3.12's tall style (separate issue).

## Decision

- **Ruleset thresholds tightened** (ruleset 18774666, `code_scanning` rule):
  `security_alerts_threshold: medium_or_higher` (was `high_or_higher`),
  `alerts_threshold: errors_and_warnings` (was `errors`). Warning-level CodeQL findings
  — including *quality* findings from the suite — now block PRs that introduce them.
  Not `all`: note-level findings are style-grade and would gate on noise.
- **`flutter analyze --fatal-infos`** in CI: any reported diagnostic fails, not just
  errors/warnings. Free because the tree is clean; keeps it that way.
- **`strict-inference: true`** joins strict-casts/strict-raw-types in
  `analysis_options.yaml`; the 6 findings fixed with explicit type arguments.
- **actionlint job**: lints workflow files (expressions, contexts, shellcheck on run
  blocks) — pinned v1.7.7.
- **Android Lint job** (`:app:lintDebug`) with `warningsAsErrors = true` and a committed
  **baseline** (`android/app/lint-baseline.xml`) freezing the 44 pre-existing warnings:
  new warnings fail; the baseline is a burn-down list (follow-up issue), never to grow.
- **dependency-review job** on PRs (`fail-on-severity: low`): a PR adding a dependency
  with any known vulnerability is blocked. Repo-side, **Dependabot alerts + security
  updates enabled**, and `.github/dependabot.yml` opens weekly update PRs (pub, gradle,
  github-actions) that flow through the normal merge gate.
- **After this lands on `main`**, `actionlint`, `android-lint`, and `dependency-review`
  are added to the ruleset's required status checks (the command is in PR body/issue —
  doing it before the jobs exist on main would deadlock every open PR).

## Rejected / deferred

- `security-experimental` CodeQL pack — FP noise (above).
- CodeQL `threat-models: local` for Kotlin — treats local files/env as tainted sources;
  on a local-first personal app this flags its own storage reads. Not worth it.
- `alerts_threshold: all` — note-level gating is style noise.
- **`dart format` gate** — right, but needs a one-time 271-file mechanical reformat that
  would drown this PR and conflict with every open PR; split to its own issue (band 1).
- **detekt/ktlint for Kotlin** — real value beyond Android Lint (style/complexity), but
  needs plugin wiring + its own baseline; split to its own issue for evaluation.
- GitHub Code Quality / coverage rules — still plan-locked (decision-11) — our
  coverage-gate floor + no-drop ratchet already cover the coverage half.

## Consequences

- New-code strictness rises across every language in the repo (Dart analyzer, CodeQL
  Kotlin+Actions, Android Lint, actionlint) with zero big-bang cleanup forced: baselines
  freeze existing debt as visible burn-down lists instead.
- Two follow-up issues: dart-format adoption; detekt/ktlint evaluation; plus the lint
  baseline burn-down.
- Dependabot PRs arrive weekly and consume implementer/reviewer loop capacity — capped
  at 5 per ecosystem.
