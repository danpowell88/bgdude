# Decision 17 — bgdude stays foreground-only; no `ACCESS_BACKGROUND_LOCATION`

- **Date:** 2026-07-19
- **Status:** proposed (agent finding — needs Summer's sign-off)
- **Context:** issue #376 (permissions completeness audit), AC "Background-location need is
  explicitly decided"

## Decision

bgdude does **not** declare or request `ACCESS_BACKGROUND_LOCATION`. No feature needs the
device's position, in the foreground or otherwise.

## Why

The only reason location appears in this app at all is that **Android 11 and below require
`ACCESS_FINE_LOCATION` to perform a BLE scan** — a legal requirement about scanning, not a
use of position. That declaration already carries `maxSdkVersion="30"`, and on API 31+ the
split `BLUETOOTH_SCAN` permission (with `neverForLocation`) replaces it.

The one plausible candidate for genuine location use was weather context, and it does not
need it: `WeatherSettings` takes a **user-typed city name**, geocodes it once, and stores
`lat`/`lon`. Nothing calls a positioning API — there is no `Geolocator` or
`getCurrentPosition` anywhere in `lib/`.

Requesting background location would also be actively costly: it triggers Play Store's
sensitive-permission review, and Android forces it into a separate second prompt that users
overwhelmingly decline. Asking for something no feature reads is a bad trade.

## Consequences

- Any future GPS-based feature (auto weather by current location, geofenced reminders)
  re-opens this decision and must add the **two-step** prompt: foreground location first,
  background only afterwards, per Android's requirement.
- **One such feature is already proposed: issue #377** (weather from device GPS, opt-in).
  It does not invalidate this decision — #377 is explicitly opt-in and *foreground*
  location, which is a different permission from the background one ruled out here. But
  it does mean the sentence "no feature reads position" is true **today** rather than
  permanently, and whoever implements #377 should re-read this file first.
- `permissionsForSdk` in `lib/state/permission_audit.dart` intentionally lists
  `locationWhenInUse` only for `maxSdk: 30`, mirroring the manifest.

## Open risk this decision does NOT resolve

`minSdk` is **29**, and `PumpService` is started from `BootReceiver` — so on Android 10/11
the app can be scanning for the pump with no UI on screen. On those versions, background
BLE scan results are gated by location: an app judged to be in the background without
`ACCESS_BACKGROUND_LOCATION` gets **zero scan results, with no error**. Whether a
`foregroundServiceType="connectedDevice"` service is judged foreground for that check —
and whether the type would need to include `location` — has **not been verified on a real
API 29/30 device**, and cannot be verified in this environment.

This is not an argument for requesting background location; it is an argument for
**testing that path or raising `minSdk` to 31**. Tracked as a follow-up to #376 rather than
silently assumed to work.
