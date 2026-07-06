---
id: TASK-8
title: P1-1 DB passphrase → Keystore (flutter_secure_storage)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §1-P1
  - phase-0
  - security
dependencies: []
priority: high
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
At-rest encryption is theatre: the SQLCipher passphrase sits in plaintext SharedPreferences next to the ciphertext while comments/README claim Keystore. Move to flutter_secure_storage (Keystore), migrate off prefs, await the write, and fix the false comments.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Passphrase stored via flutter_secure_storage/Keystore
- [ ] #2 Migrated off SharedPreferences
- [ ] #3 Write awaited before DB open
- [ ] #4 False security comments corrected
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P1-1 (headline issue #2)
Effort: S
Where: secure_key.dart, database.dart:187, main.dart
Roadmap status: open
<!-- SECTION:NOTES:END -->
