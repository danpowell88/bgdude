---
id: TASK-113
title: 'Strengthen analyzer lints (stream safety, dynamic calls) and fix fallout'
status: To Do
assignee: []
created_date: '2026-07-06 04:56'
labels:
  - code-health
  - infra
dependencies: []
priority: medium
ordinal: 113000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `analysis_options.yaml:14-20` layers only 5 rules on top of flutter_lints. For a BLE/CGM streaming app (7 files use StreamController/StreamSubscription/.listen), the absence of `cancel_subscriptions` and `close_sinks` means subscription and controller leaks are never flagged. Also missing: `avoid_dynamic_calls` (relevant to the untyped bridge payload maps), `only_throw_errors`, `throw_in_finally`, `discarded_futures`, `directives_ordering`.

**Reason for change.** These lints catch the exact bug classes this app is most exposed to (leaked stream subscriptions in long-running services, typos on dynamic bridge payloads) at compile time instead of on-device.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 cancel_subscriptions, close_sinks and avoid_dynamic_calls enabled at minimum; the other candidates evaluated and either enabled or rejected with a comment in analysis_options.yaml
- [ ] #2 flutter analyze clean after fixing all violations (fix, do not suppress; per-line ignores only with a justification comment)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Enable the lints one at a time; triage the violation list for each.
- Fix real leaks properly (cancel in dispose, close controllers); no blanket ignores.
- Consider basing on package:lints/recommended + flutter_lints while in the file.
- flutter analyze clean, flutter test green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (test finding 6)
- Effort: S–M
- Where: analysis_options.yaml:14-20
<!-- SECTION:NOTES:END -->
