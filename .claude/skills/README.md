# Agent skills for bgdude

Project-scoped [Agent Skills](https://code.claude.com/docs/en/skills) that live in the repo
so **every** session and agent working here (Claude Code, and other SKILL.md-compatible
agents) picks them up automatically. Each skill is a folder with a `SKILL.md`: YAML
frontmatter (`name`, `description` — used to decide when the skill applies) plus markdown
instructions.

These are **vendored copies** of publicly available, permissively licensed skills. Upstream
license texts are in [`licenses/`](licenses/); keep them when adding or updating a vendored
skill. To refresh a skill, re-copy it from its source (below) rather than hand-editing, so it
stays a faithful mirror.

## Vendored skills

| Skill | What it does | Source | License |
|-------|--------------|--------|---------|
| `github/` | `gh` CLI for issues, PRs, CI runs, and `gh api` queries (incl. a CI-failure debugging flow). | [Dimillian/Skills](https://github.com/Dimillian/Skills) (`github`) | MIT |
| `android-cli/` | The `android` CLI: AVDs/emulators, screenshots & UI inspection, SDK components, project run — supports the repo's emulator integration tests and screenshot generation. | [android/skills](https://github.com/android/skills) (`devtools/android-cli`) | Apache-2.0 |
| `flutter-add-integration-test/` | Convert app interactions into permanent `integration_test/` tests via Flutter Driver. | [flutter/skills](https://github.com/flutter/skills) | BSD-3-Clause |
| `flutter-add-widget-preview/` | Add interactive widget previews (`previews.dart`). | flutter/skills | BSD-3-Clause |
| `flutter-add-widget-test/` | Component-level `WidgetTester` tests for rendering + interaction. | flutter/skills | BSD-3-Clause |
| `flutter-apply-architecture-best-practices/` | Structure the app with the recommended layered (UI / Logic / Data) architecture. | flutter/skills | BSD-3-Clause |
| `flutter-build-responsive-layout/` | Build layouts that adapt across screen sizes. | flutter/skills | BSD-3-Clause |
| `flutter-fix-layout-issues/` | Diagnose and fix overflow / constraint / layout errors. | flutter/skills | BSD-3-Clause |
| `flutter-implement-json-serialization/` | Add `json_serializable` model (de)serialization. | flutter/skills | BSD-3-Clause |
| `flutter-setup-declarative-routing/` | Set up declarative navigation (`go_router`). | flutter/skills | BSD-3-Clause |
| `flutter-setup-localization/` | Add localization (`flutter_localizations` / ARB). | flutter/skills | BSD-3-Clause |
| `flutter-use-http-package/` | Networking with the `http` package. | flutter/skills | BSD-3-Clause |

The `flutter-*` set is the official Flutter team's skills (BSD-3-Clause, © The Flutter
Authors); `android-cli` is from Google's official [android/skills](https://github.com/android/skills)
(Apache-2.0); `github` is Thomas Ricouard's (MIT).

**Why only one skill from `android/skills`?** That repo is excellent but aimed at *native*
Android app development — most of it (Jetpack Compose, navigation, Wear, XR, Play billing,
CameraX, edge-to-edge) doesn't apply to a Flutter app that owns its own UI. Only
`devtools/android-cli` maps cleanly to bgdude's actual native surface (emulator/AVD +
screenshots). Situational others worth opting into later: `performance/r8-analyzer`
(release shrinking/keep-rules), `build/agp/agp-9-upgrade` (AGP migrations),
`security/android-intent-security`.

## How this fits the repo's conventions

The `github` skill is a **general** `gh` reference. This repo's **specific** issue workflow —
the `status:*` label pipeline, the claim protocol, ordinals, `implemented-by:` /
`friction:` comment tags — lives in the root `CLAUDE.md` ("GitHub Issues" section). Use the
skill for the mechanics of `gh` and `CLAUDE.md` for how we drive issues here.

## Suggested additional skills

Candidates worth adding next (bespoke, since no clean public equivalent fits this codebase):

- **drift-sqlcipher** — schema/migrations, generated code, and the encrypted-DB setup this app
  uses (`lib/data/database.dart`, the one committed `*.g.dart`).
- **pumpx2-native-bridge** — the read-only t:slim X2 BLE MethodChannel bridge and Robolectric
  tests; verify pumpx2 APIs via `javap` before writing (see the `CLAUDE.md` native notes).
- **coverage-ratchet** — add tests in the same change as new code so the CI coverage gate never
  regresses (the repo's per-ticket ratchet).
- **user-guide-sync** — keep `doc/user-guide.html` (and `doc/index.html`) current on any
  user-visible change (a standing `CLAUDE.md` rule).
- **android-release** — signing, Play internal track, versioning (the 16 KB native-library
  alignment audit is now enforced by the `native-lib-alignment` CI job, not a manual checklist).
