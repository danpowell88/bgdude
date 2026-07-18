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

### Live capture from a real pump (Protocol Explorer sweep)
Captured on-device from the spare test pump (**t:slim X2, serial 868643, API 3.4/JPAKE**,
active IDP "Gym only") by running the Protocol Explorer **Sweep all reads**. Opcodes are
decimal; cargo is the raw response bytes; fields are pumpx2's decoded values.

| Message | Op | Cargo (hex) | Key decoded fields |
|---|---|---|---|
| **HomeScreenMirrorResponse** | 57 | `00 ff c8 c8 c8 04 00 00 00` | `apControlStateIcon=STATE_GRAY`, `basalStatusIcon=SUSPEND`, `bolusStatusIcon=HIDE_ICON`, `cgmAlertIcon=NO_ERROR`, `cgmTrendIcon=NO_ARROW`, `cgmDisplayData=false`, `statusIcon0/1=HIDE_ICON` |
| **PumpFeaturesV2Response** | 161 | `00 02 04 00 00 07` | `controlFeatures=[STANDARD_BOLUS_CONTROL, PREFLIGHT_CONTROL, USER_INTERACTION_CONTROL, BLOOD_GLUCOSE_ENTRY_CONTROL]`, `pumpFeaturesBitmask=117440516`, `supportedFeatureIndexId=2` |
| **PumpFeaturesV1Response** | 79 | `9a dd 24 76 00 00 00 00` | feature bitmask (older layout) |
| **PumpGlobalsResponse** | 87 | `01 f4 01 d0 07 00 01 03 01 01 01 01 01 01` | `quickBolusEnabledRaw=1`, `quickBolusIncrementUnits=500` (0.5 U), `quickBolusIncrementCarbs=2000`, `quickBolusEntryType=0`, annunciation flags (`alarm/alert/bolus/button=3/fillTubing/reminder`) |
| **PumpSettingsResponse** | 83 | `14 1e 01 0c 00 00 0f 48 00` | `autoShutdownEnabled=1`, `autoShutdownDuration=12` h, `lowInsulinThreshold=20` U, `oledTimeout=15` s, `featureLock=0`, `status=72` (byte 2 `0x1e=30` ≈ cannula-prime size) |
| **ControlIQSleepScheduleResponse** | 107 | `01 7f 28 05 a4 01 …` | schedule enabled, `days=0x7f` (all), start/end + per-slot repeats |
| **MalfunctionBitmaskStatusResponse** | 119 | `00 00 00 00 00 00 00 00` | malfunction bitmask (0 = none). **Note:** the class is `MalfunctionBitmaskStatusResponse`, not `MalfunctionStatus` as listed above |
| **CGMHardwareInfoResponse** | 97 | `38 42 54 31 41 58 00 … 02` | transmitter hardware id = ASCII **"8BT1AX"** |
| **CurrentActiveIdpValuesResponse** | 151 | `10 27 00 00 6e 00 2c 01 24 00` | active-profile live values (carb ratio 10000→1:10, ISF, target, etc.) |
| **GlobalMaxBolusSettingsResponse** | 141 | `98 3a 10 27` | max bolus `0x3a98=15000` mU (15 U) |
| **BasalLimitSettingsResponse** | 139 | `d0 07 00 00 b8 0b 00 00` | basal limits `0x07d0=2000` / `0x0bb8=3000` mU/hr |
| **RemindersResponse** | 89 | `0f 00 … 5a 00 … 46 00 c8 00 03 04` | reminder table (low-BG, high-BG, missed-bolus, site/cannula, etc.) |
| **LocalizationResponse** | 167 | `01 00 01 ff 1f 00 00` | language / units / region config |
| **CgmStatusV2Response** | 191 | `00 …` | extended sensor state (no sensor on this pump) |
| **CGMGlucoseAlertSettingsResponse** | 91 | `c8 00 00 00 00 03 50 00 00 00 00 03` | high alert `0xc8=200`, low alert `0x50=80` mg/dL |
| **CGMRateAlertSettingsResponse** | 93 | `03 00 05 03 00 05` | rise/fall rate-alert config |
| **CGMOORAlertSettingsResponse** | 95 | `14 00 01` | out-of-range alert config |

Also confirmed live: `ApiVersion` = 3.4 (`03 00 04 00`), `PumpVersion` armSwVer 635732141 / model 1002717,
`ControlIQInfoV2` (op 179) closed-loop state, `ProfileStatus`→`IDPSettings("Gym only")`→7×`IDPSegment`
matching the decode table above, and a full `HistoryLogStream` (op 129) backfill.

### ControlIQSleepSchedule (op 107) slot layout — decoded (issue #87)

The captured cargo above is recorded truncated, but the prefix decodes exactly. The
response is **four fixed 6-byte slots** (24 bytes total):

| Offset | Bytes | Meaning |
|---|---|---|
| +0 | 1 | `enabled` (0 = slot unused) |
| +1 | 1 | days bitmask, **bit 0 = Monday** … bit 6 = Sunday |
| +2 | 2 | start, minutes-of-day, little-endian |
| +4 | 2 | end, minutes-of-day, little-endian |

So `01 7f 28 05 a4 01` = enabled, all seven days, `0x0528`=1320 (22:00) to `0x01a4`=420
(07:00). An end <= start runs past midnight. On the captured pump only slot 0 was in use;
the other three came back zeroed.

> **pumpx2 1.9.0 footgun.** `MultiDay.fromBitmask` collapses *any* mask to `[MONDAY]`, and
> `MultiDay.toBitmask(ALL_DAYS)` returns `1`. The enum's `id()` values are correct bit flags
> (1, 2, 4 … 64) — it's the two helpers that are broken. Anything reading days via
> `SleepSchedule.activeDays()` will therefore under-report an every-night schedule as
> "Mondays only". Read the raw days byte instead: `slot.build()[1]` round-trips the slot
> bytes faithfully. `PumpResponseMapperTest.pumpx2_multiday_bitmask_helpers_are_still_broken`
> pins this so the workaround can be dropped when upstream fixes it.

Requests that returned **no response** on this pump/firmware (likely unsupported opcodes):
`SecretMenu`, `UnknownMobiOpcode110`, `StreamDataReadiness`, `ActiveAamBits`, `HighestAam`,
`BasalIQ*`, `CommonSoftwareInfo`, `BleSoftwareInfo`, `PumpVersionB`, `LoadStatus`,
`GetG6TransmitterHardwareInfo`, `GetSavedG7PairingCode` — their absence is itself a finding.

### Protocol Explorer (on-device discovery tool)
bgdude ships a developer screen — **Settings → Protocol Explorer** — for probing the
protocol on a live pump. It reflectively builds any `currentStatus` **request** by class
name and shows the raw cargo bytes plus pumpx2's decoded fields (`jsonToString()` /
`verboseToString()`), so undocumented fields can be discovered without writing a hand-mapper
first. This is the fastest way to fill in the tables above from a real pump.

- **Read-only by construction.** `ProtocolProbe.buildSafeRequest` (native) refuses anything
  that is not an unsigned `CURRENT_STATUS` request with `modifiesInsulinDelivery == false`
  and `signed == false`, and only ever resolves classes inside
  `com.jwoglom.pumpx2.pump.messages.request.currentStatus`. A control/authorization/stream/
  signed message can never be *built*, so it can never be *sent* — a defensive layer on top
  of the never-enabled `enableActionsAffectingInsulinDelivery` gate. Covered by
  `ProtocolProbeTest`.
- **Catalog.** The pumpx2 1.9.0 message set exposes ~67 `currentStatus` request types. Beyond
  the ones above, notable reads the Explorer surfaces for discovery: `PumpVersionB`,
  `CommonSoftwareInfo` / `BleSoftwareInfo`, `Localization`, `Reminders` / `ReminderStatus`,
  `GlobalMaxBolusSettings`, `BasalLimitSettings`, `CurrentActiveIdpValues`,
  `BasalIQStatus/Settings/AlertInfo`, `CgmStatusV2`, the CGM alert-settings reads,
  `GetG6TransmitterHardwareInfo` / `GetSavedG7PairingCode`, `LoadStatus`,
  `StreamDataReadiness`, `ActiveAamBits` / `HighestAam`, `BolusCalcDataSnapshot`, and the
  intriguingly-named **`SecretMenu`** and **`UnknownMobiOpcode110`** (reverse-engineered but
  unnamed). Firing these and recording the decoded output is how new rows get added here.
- **Parametric reads.** `IDPSegment(idpId, segment)` and `HistoryLog(startSeq, count)` take
  two integer args (exposed as inline fields); everything else is a zero-cargo read.

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
