---
id: decision-11
title: >-
  CodeQL code-scanning gate on main (Kotlin + Actions); GitHub Code Quality /
  coverage rules unavailable on a user-owned Free repo
date: '2026-07-10 13:31'
status: accepted
---
## Context

- After decision-10's PR merge gate, we wanted three more ruleset rules if free: **Require code
  scanning results**, **Require code quality results**, and **Restrict code coverage** (preview).
- Investigated 2026-07-10: **GitHub Code Quality is "available for organization-owned
  repositories on GitHub Team and GitHub Enterprise Cloud plans"** — this repo is user-owned on
  Free, so the code-quality rule AND the coverage rule (which requires Code Quality enabled +
  `actions/upload-code-coverage`, Cobertura format) are both unavailable here at any price short
  of moving the repo into a paid org. Even on Team, quality analysis supports only
  C#/Go/Java/JS/Python/Ruby/TS — **neither Dart nor Kotlin** — so it would analyze nothing.
- **Code scanning (CodeQL) IS free on public repos.** Supported languages present here:
  `java-kotlin` (the `android/` native code) and `actions` (workflow files). **CodeQL does not
  support Dart** — the Flutter bulk stays covered by our own analyze/test/coverage-gate checks.

## Decision

- **Enabled CodeQL via an advanced-setup workflow** (`.github/workflows/codeql.yml`), NOT
  default setup: default setup was tried first, but its `autobuild` cannot build a Flutter
  Android app (no Flutter SDK / `local.properties`), the `java-kotlin` job failed, and its
  "Adjust Configuration" step silently dropped the language — leaving only workflow files
  scanned. The workflow analyzes `actions` (buildless) and `java-kotlin` via a manual traced
  compile (`:app:compileDebugKotlin :app:compileDebugUnitTestKotlin`, same toolchain steps as
  ci.yml's native-tests job). Triggers: every push to `main` (deliberately NO paths filter —
  the ruleset needs results on the ref, and bookkeeping commits land constantly), PRs to
  `main`, and a weekly schedule. All free on a public repo.
- **Added the `code_scanning` rule to the "main merge gate: PR + green CI" ruleset**
  (id 18774666): tool `CodeQL`, `security_alerts_threshold: high_or_higher`,
  `alerts_threshold: errors`. A PR cannot merge while CodeQL analysis is missing/in progress or
  found a high+ security alert / error-level alert.
- **Code-quality and coverage rules: not adopted** (unavailable, see Context). Their intent is
  already covered in-house: the `coverage-gate` required check enforces the ratcheting line
  coverage floor (min-threshold ≈ "Restrict code coverage"), and `flutter analyze` +
  the review loop cover quality. Revisit only if the repo ever moves into a Team/Enterprise org
  AND CodeQL quality adds Dart/Kotlin.

## Consequences

- The merge gate now also demands CodeQL results: `gh pr checks` shows the CodeQL runs; a
  just-merged `main` may briefly lack results while its push analysis runs — a reviewer seeing
  "waiting for code scanning results" should wait for the run, never bypass.
- Direct bookkeeping pushes to `main` bypass this rule like the others (admin bypass,
  "Bypassed rule violations" message is expected and fine).
- Kotlin/workflow changes get real static security analysis; Dart does not (unsupported) —
  don't mistake a green CodeQL check for Dart coverage.

## Addendum (2026-07-10, same day): free in-house equivalents implemented

- Unavailability re-verified empirically, not just from docs: the repo's
  `security_and_analysis` settings expose no `code_quality` capability (a PATCH enabling it is
  silently ignored), and the rulesets API rejects the `code_quality` rule type with a 422
  ("matches no possible input") — the rule is not in the API schema for this repo.
- **Code-quality equivalent:** `codeql.yml` now runs the `security-and-quality` query suite for
  both languages. Quality findings surface as code scanning alerts, so the existing ruleset
  rule (`alerts_threshold: errors`) blocks merges on error-level quality results — the same
  semantics as GitHub's "Require code quality results" at "Severity: Errors". Warning-level
  quality findings surface without blocking.
- **Coverage-restrict equivalent:** the `coverage-gate` job (already a required check) now
  enforces both halves of GitHub's "Restrict code coverage": the existing 65% floor
  (= minimum coverage percentage) plus a new **no-drop ratchet** (= maximum coverage drop 0):
  every run uploads its coverage % as a `coverage-percent` artifact, and on PRs the job
  downloads the latest successful main run's baseline and fails if the PR's coverage is more
  than 0.1pt below it. This machine-enforces the CLAUDE.md "coverage is a ratchet, per ticket"
  convention that was previously review-enforced only.
- Revisit the native GitHub features only if the repo moves into a Team/Enterprise org.
