---
name: pumpx2-native-bridge
description: "Work on bgdude's native Android/t:slim X2 pump bridge (Kotlin, pumpx2 over BLE via MethodChannel). Use when touching anything under android/app/src/main/kotlin/com/bgdude/app/pump/, mapping pump responses, or adding pump reads. CRITICAL — the app is READ-ONLY toward the pump by charter; never send control/authorization/signed messages. Verify pumpx2 APIs with javap before writing against them."
---

# The pumpx2 native bridge (read-only by charter)

The native pump code lives in `android/app/src/main/kotlin/com/bgdude/app/pump/`. It talks to
a Tandem t:slim X2 over BLE using the **pumpx2** library (`com.jwoglom.pumpx2`, pulled from
JitPack) and bridges to Dart via **MethodChannel** (`PumpChannels.kt`, `PumpBridge.kt`,
`PumpHostApiImpl.kt`) — this project uses plain MethodChannel, **not** Pigeon codegen.

## The read-only charter is the core safety invariant — never weaken it
bgdude only ever **reads** from the pump. It must never modify insulin delivery.

- `PumpCommHandler` is the read-only handler; pumpx2's own
  `enableActionsAffectingInsulinDelivery` gate is **never** enabled.
- `ProtocolProbe.buildSafeRequest` is a defensive second layer, enforcing the guarantee **by
  construction**: it refuses anything that is not an unsigned `CURRENT_STATUS` request from
  `com.jwoglom.pumpx2.pump.messages.request.currentStatus`. A control / authorization /
  stream / signed message, or a class outside that package, can never be built, so it can
  never be sent.
- When adding a pump read, add it as a `currentStatus` request and route it through the
  existing safe path. Never introduce a code path that could send a signed/control message.
  Any change here shows up in `ProtocolProbeTest` — keep that test meaningful.

## Verify pumpx2 APIs before writing against them
Native code is buildable/testable here, but pumpx2's API surface is easy to guess wrong.
Before calling into it, confirm the real signatures with `javap` on the cached jar (see the
`pumpx2-native-verification` note) rather than assuming method/field names.

## Response mapping — units matter
`PumpResponseMapper.kt` converts raw pump values to app units, including **milliunits →
units** (mU→U) insulin conversions. Getting a factor wrong silently corrupts every downstream
metric. `PumpResponseMapperTest` guards these — extend it for any new mapping.

## Tests are BLOCKING (Robolectric)
Run: `cd android && ./gradlew :app:testDebugUnitTest`. The suite is a required CI gate. It
covers the charter (`ProtocolProbeTest`), mappings (`PumpResponseMapperTest`,
`PumpHistoryMapperTest`, `PumpProfileMapperTest`), pairing/timeout concurrency, service
lifecycle, and threading. When you fix a concurrency bug here, remember visibility ≠
atomicity (`@Volatile` doesn't make a read-modify-write atomic) and ship a test that fails if
the fix is reverted.
