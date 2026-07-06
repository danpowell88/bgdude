---
id: decision-4
title: What NOT to change - architectural keeps from the 2026-07 structural survey
date: '2026-07-06 08:47'
status: accepted
---
## Context

The 2026-07-06 structural survey (162 files / ~33.9k lines) found the codebase healthy in specific, deliberate ways that refactoring enthusiasm could easily destroy: `core` is genuinely foundational (67 importers, zero imports), `analytics/` is fully pure, there was one layering violation in the whole tree, the `PumpSource`/simulator seam is clean, everything goes through Riverpod (no service locator), and there are no upward or circular dependencies.


## Decision

Keep, do not "improve":

- **The layering itself** — directory discipline plus the architecture guard test (TASK-41) beats a package split at this size.
- **The `PumpSource`/simulator seam** — extend the pattern to new integrations (meter, Nightscout) instead of inventing new seams.
- **Hand-written Riverpod** — no riverpod codegen migration; do not entangle refactors with a framework change.
- **Pure constructor-injected `analytics/` + `ml/`** — they take explicit `DateTime`/data arguments; keep that style.
- **The `pumpDemoApp` integration-test harness** — it covers screen flows well; widget tests only for the 3-4 screens with real widget-layer logic.


## Consequences

