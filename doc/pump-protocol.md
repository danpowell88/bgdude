# t:slim X2 (pumpx2) BLE protocol — developer reference

Notes on the Tandem t:slim X2 Bluetooth protocol as used by bgdude, plus reads the app
doesn't surface yet. Verified against a real (spare) pump over BLE. Everything here is
**read-only**: bgdude only ever sends `currentStatus` request messages and never a
`control` (insulin-affecting) message. This doc reflects the reverse-engineered
[jwoglom/pumpX2](https://github.com/jwoglom/pumpX2) library (v1.9.0) that our native layer
wraps.

> **Read-only guarantee.** The read-only property is enforced by construction: nothing from
> `request.control` is imported in `PumpCommHandler`, `enableActionsAffectingInsulinDelivery`
> is never called, and on desktop-recon tooling the CONTROL / CONTROL_STREAM characteristics
> are hard-blocked. See `android/.../pump/PumpCommHandler.kt`.

## BLE transport

- **Service UUID:** `0000fdfb-0000-1000-8000-00805f9b34fb`
- **Characteristics** (base `7b83fffX-9f77-4e5c-8064-aae2c24838b9`):

  | Char | Role | Props |
  |------|------|-------|
  | `fff6` | CURRENT_STATUS (read requests + responses) | write, notify |
  | `fff7` | QUALIFYING_EVENTS (async "something changed") | notify |
  | `fff8` | HISTORY_LOG stream | notify |
  | `fff9` | AUTHORIZATION (pairing handshake) | write, notify |
  | `fffc` | CONTROL (signed, insulin-affecting) — **never used** | write, notify |
  | `fffd` | CONTROL_STREAM — **never used** | notify |

- **Framing.** Each message = `[opcode][txId][len][cargo…][CRC16]`, chunked into ≤~18-byte
  BLE packets. Each packet on the wire is `[packetsRemaining][txId][chunk]`; the receiver
  reassembles by counting `packetsRemaining` down to 0. `currentStatus` reads are **plaintext
  + CRC16 only** (unsigned). Only `control` messages carry a 24-byte `timeSinceReset +
  HMAC-SHA1` trailer and route to the CONTROL characteristic.

## Pairing / auth

Two schemes exist; the pump picks by firmware/API version:

- **JPAKE (6-digit code)** — newer firmware (our test pump, API 3.4). Five-round
  password-authenticated key exchange (`Jpake1a/1b/2/3-session-key/4-key-confirmation`) on
  the AUTHORIZATION characteristic; ends in `HMAC SECRET VALIDATES`. Yields a 32-byte derived
  secret; later connections can re-auth with it (`initializeWithDerivedSecret`) **without a
  new code**.
- **Challenge-response (16-char code)** — older firmware. `CentralChallenge` →
  `PumpChallenge` HMAC-SHA1 keyed by the code's ASCII.

**BLE bonding.** After the first pairing the pump requires an **LE Secure Connections**
encrypted link for its pumpx2 characteristics. Android's BLE stack forms this bond as part
of pairing (so the app works). Desktop `bleak`/WinRT cannot form a bond the pump accepts
(unbonded → GATT `Insufficient Authentication`; a WinRT Just-Works bond → key mismatch →
link drop), which is why full desktop recon is limited — see
[`pump-recon-findings.md`](pump-recon-findings.md). The app's real path is the on-device
Android native layer.

## Read messages

### Used by bgdude today
`ApiVersion`, `PumpVersion`, `TimeSinceReset`, `CurrentBattery` (v1/v2), `InsulinStatus`,
`ControlIQIOB` / `NonControlIQIOB`, `ControlIQInfo` (v1/v2), `CurrentBasalStatus`,
`CurrentEGVGuiData` (CGM), `LastBolusStatusV2`, `AlertStatus`, `AlarmStatus`, `CGMStatus`,
`ProfileStatus` → `IDPSettings` → `IDPSegment` (the therapy profile).

### Undocumented / not surfaced yet (opportunities)
| Message | What it gives | Possible bgdude use |
|---|---|---|
| **HomeScreenMirror** | The exact icons on the pump screen (basal state, AP/Control-IQ state, CGM trend arrow, status icons) | A live "what my pump shows right now" panel |
| **PumpFeatures** (v1/v2) | Enabled features (Dexcom G6, Control-IQ, basal-limit, BLE control, settings-in-IDP…) | Adapt UI to what the pump actually supports |
| **PumpGlobals** | Quick-bolus config + annunciation settings | Show/verify quick-bolus setup |
| **PumpSettings** | Auto-shutdown, cannula prime size, low-insulin threshold, OLED timeout, feature-lock | Settings mirror / reminders |
| **ControlIQSleepSchedule** | Sleep-activity schedule (start/end/days) | Explain Control-IQ sleep behaviour on the timeline |
| **MalfunctionStatus** | Pump malfunction state | Proactive safety alert |
| **CGMHardwareInfo** | Transmitter hardware id | Diagnostics |

### Field encodings (from `IDPSegment` and friends)
- Basal rate: **milliU/hr** (850 → 0.85 U/hr).
- Carb ratio: **×1000** (10000 → 1:10 g/U; 9000 → 1:9).
- ISF / target BG: **mg/dL** as-is (30, 108).
- Segment start time: **minutes past midnight** (0, 180=03:00, 1320=22:00).
- Max bolus / insulin amounts: milliU (15000 → 15 U). Insulin duration (DIA): minutes (180).

### Example decode (spare test pump, active IDP "Gym only", 7 segments)
| Seg | Start | Basal | Carb ratio | ISF | Target |
|---|---|---|---|---|---|
| 0 | 00:00 | 0.85 | 1:10 | 30 | 108 |
| 1 | 03:00 | 0.85 | 1:9  | 30 | 108 |
| 2 | 09:00 | 0.70 | 1:10 | 36 | 108 |
| 3 | 12:00 | 0.65 | 1:10 | 36 | 108 |
| 4 | 18:00 | 0.90 | 1:10 | 36 | 108 |
| 5 | 22:00 | 0.80 | 1:10 | 36 | 108 |
| 6 | 23:00 | 0.80 | 1:10 | 36 | 108 |

## History log
`HistoryLogStatusRequest` returns the first/last sequence numbers; `HistoryLogRequest(start,
count)` streams historical events (boluses, basal changes, alarms, cartridge/site changes,
CGM readings, …) on the HISTORY_LOG characteristic — 130+ event types. bgdude uses this for
backfill (`PumpHistoryMapper`); decoding is partial/best-effort on hardware.
