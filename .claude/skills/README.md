# Agent skills for bgdude

Project-scoped [Agent Skills](https://code.claude.com/docs/en/skills) that live in the repo
so **every** session and agent working here (Claude Code, and other SKILL.md-compatible
agents) picks them up automatically. Each skill is a folder with a `SKILL.md`: YAML
frontmatter (`name`, `description` — used to decide when the skill applies) plus markdown
instructions.

Two kinds live here: **vendored** copies of public, permissively licensed skills, and
**bespoke** skills written for this codebase.

## Vendored skills (public, mirrored verbatim)

Upstream license texts are in [`licenses/`](licenses/); keep them when adding or updating a
vendored skill. To refresh one, re-copy it from its source rather than hand-editing, so it
stays a faithful mirror.

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

## Bespoke skills (written for this repo)

These encode bgdude-specific knowledge with no clean public equivalent. Edit them directly as
the codebase evolves.

| Skill | What it does |
|-------|--------------|
| `bgdude-issues/` | The full GitHub-Issues workflow: the `status:*` pipeline, gh cheat-sheet, ordinals/body structure, claim/finish/blocked steps, comment + `friction:` tags, and the PRs-never-close-issues rule. |
| `verify-build/` | The CI-equivalent local pipeline to run before committing (codegen → analyze → coverage-gated test → APK → native Kotlin tests), plus the `dart run` dev-env gotcha. |
| `coverage-ratchet/` | The per-ticket coverage discipline: ship tests with new code; how CI computes coverage (excluding `database.g.dart`) and enforces no-drop vs `main`. |
| `bug-sweep/` | The four-axis "sweep the whole surface" checklist for any bug fix (sibling sites, both branches, a test that fails when reverted, concurrency/security nuance). |
| `drift-sqlcipher/` | The encrypted drift/SQLCipher store: mandatory codegen, `schemaVersion`/downgrade guards, and the Keystore passphrase failure modes not to paper over. |
| `pumpx2-native-bridge/` | The native Kotlin ↔ t:slim X2 pump bridge (pumpx2 over BLE via MethodChannel). **Read-only by charter** — never send control/signed messages; verify pumpx2 APIs with `javap`. |
| `integration-test-harness/` | Adding/running on-device tests under `integration_test/` (demo-mode harness), how to run a single file on an emulator, and the `flutter drive` caveat. |
| `user-guide-sync/` | Keep `doc/user-guide.html` (and `doc/index.html`) current on any user-visible change; regenerate screenshots for new screens. |
| `android-release/` | Versioning/build-types/R8, and the still-open distribution+signing decision (issue #113) — don't invent a signing/store flow. |

The general `github` skill covers `gh` mechanics; `bgdude-issues` covers **how we drive issues
here**. Much of the root `CLAUDE.md` now points into these skills for detail (its *GitHub
Issues*, *Verify the build*, *Fixing a bug*, and *Emulator tests* sections) — keep the skill
and its CLAUDE.md pointer in sync when either changes.

## Further opt-ins

`android/skills` has situational skills we didn't vendor (native-Android-focused overall):
`performance/r8-analyzer` (release keep-rules), `build/agp/agp-9-upgrade` (AGP migrations),
`security/android-intent-security`. Add if/when the need arises.
