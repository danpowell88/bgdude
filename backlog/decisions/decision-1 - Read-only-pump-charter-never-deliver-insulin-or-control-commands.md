---
id: decision-1
title: Read-only pump charter - never deliver insulin or control commands
date: '2026-07-06 08:02'
status: accepted
---
## Context

bgdude is a companion app for a Tandem t:slim X2 insulin pump built on the pumpx2 library, which also exposes control (bolus/insulin-delivery) APIs. Any control capability would change the app's safety class entirely.


## Decision

The app is strictly read-only: it never delivers insulin, never sends control commands, and never exposes the pumpx2 control surface. Every number the app suggests is shown with its working and confirmed by the user before it matters.


## Consequences

