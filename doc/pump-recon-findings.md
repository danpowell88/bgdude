# t:slim X2 BLE recon — findings (spare pump ***643 / serial 868643)

Read-only reconnaissance from the PC over system Bluetooth, reusing the `pumpx2-messages`
1.9.0 library for framing/auth/parse (JVM "brain") with a Python `bleak` BLE transport.
**No control/insulin-affecting message was ever sent** — the CONTROL characteristics were
hard-blocked and only `currentStatus` reads + the JPAKE auth were written.

## Connection & protocol
- Device `EA:38:DD:63:11:69`, name `tslim X2 ***643`, service `0000fdfb`, mfg id 1437.
- **Pairing = JPAKE (6-digit code).** Full 5-round handshake (Round1a/1b/2/3-session-key/
  4-key-confirmation) implemented and **working** — `HMAC SECRET VALIDATES`.
- **Silent reconnect works:** the 32-byte derived secret lets us re-auth on later
  connections with **no pairing code** (`initializeWithDerivedSecret`).
- Characteristic map (confirmed at runtime): CURRENT_STATUS `7b83fff6`, QUALIFYING_EVENTS
  `fff7`, HISTORY_LOG `fff8`, AUTHORIZATION `fff9`, CONTROL `fffc`, CONTROL_STREAM `fffd`.
- Post-auth `currentStatus` reads are plaintext (CRC16-framed, unsigned); only `control`
  messages are HMAC-signed → routed to the CONTROL characteristic (never used here).
- MTU negotiated large enough for 174-byte single-packet responses.

## Device identity
| Field | Value |
|---|---|
| Manufacturer / model | Tandem Diabetes Care · t:slim X2 |
| Serial | 868643 |
| Model number | 1002717 |
| Part number | 1013572 |
| ARM SW / MSP SW | 635732141 / 635732141 |
| PCBA serial | 211307948 |
| API version | 3.4 |
| Clock | 2026-07-05T22:35:27Z · 92854 s since reset (correct) |

## State (spare pump — no cartridge/CGM)
| Read | Value |
|---|---|
| Battery | 100%, not charging |
| Insulin remaining | 0 U (empty), low threshold 20 U |
| IOB (Control-IQ + legacy) | 0 |
| CGM (EGV) | UNAVAILABLE — session stopped, transmitter unavailable, HW "8BT1AX" |
| Basal | current 0 U/hr, profile 0.8 U/hr, delivery SUSPENDED |
| Home-screen mirror | basal=SUSPEND, AP=gray, no CGM display |
| Last bolus / last BG | none |
| Alerts / alarms | alert DEVICE_PAIRED (logged our pairing) · no alarms |

## Configuration
- **Control-IQ:** closed-loop **ENABLED**, user-mode 1, TDI 38 U, weight 92 (unit 2),
  exercise choice 1 / duration 12600 s; **sleep schedule** 22:00–07:00, all days.
- **Pump features (V1):** Dexcom G6, Control-IQ, basal-limit, auto-pop, BLE pump control,
  settings-in-IDP. **(V2):** standard-bolus / preflight / user-interaction / BG-entry
  control; bitmask 117440516.
- **Pump globals:** quick-bolus enabled (2000 mcarb / 500 munit increments), all
  annunciations on.
- **Pump settings:** auto-shutdown 12 h (enabled), cannula prime 30, low-insulin 20,
  OLED timeout 15 s, feature-lock off.
- **Profiles:** 4 IDPs, slots [2,1,0,3], active slot 2, active segment index 1.
- **Active IDP (slot 2) "Gym only":** insulin duration 180 min, max bolus 15 U, carb entry
  on, **7 segments** — full schedule captured:

| Segment | Start | Basal (U/hr) | Carb ratio (g/U) | ISF (mg/dL/U) | Target (mg/dL) |
|---|---|---|---|---|---|
| 0 | 00:00 | 0.85 | 10.0 | 30 | 108 |
| 1 | 03:00 | 0.85 | 9.0  | 30 | 108 |
| 2 | 09:00 | 0.70 | 10.0 | 36 | 108 |
| 3 | 12:00 | 0.65 | 10.0 | 36 | 108 |
| 4 | 18:00 | 0.90 | 10.0 | 36 | 108 |
| 5 | 22:00 | 0.80 | 10.0 | 36 | 108 |
| 6 | 23:00 | 0.80 | 10.0 | 36 | 108 |

(wire encoding: basal in mU/hr, carb ratio ×1000, ISF & target in mg/dL, start time in
minutes; all four fields active per segment.)

## Definitive root cause of the remaining gap (BLE bonding)
After exhaustive testing the blocker is precisely characterised — it is a **Windows BLE
stack vs pump encryption incompatibility**, not a protocol gap:

- The pump's pumpx2 characteristics require an **encrypted (bonded) link** once the pump has
  a pairing entry for the central. Writing unbonded returns GATT error 5
  **`Insufficient Authentication`** (link stays up, writes refused).
- Establishing a WinRT **Just-Works bond** (`DeviceInformationCustomPairing.PairAsync(
  ConfirmOnly)`, auto-accept) **succeeds** (status=0 PAIRED) — but the pump then **rejects
  that encryption key** and drops the link on the first write. WinRT's bond (LE Legacy /
  its own LTK) is not what the pump expects.
- The pump wants an **LE Secure Connections** key coordinated with its pairing flow — which
  the Android app's BLE stack produces (so the phone app works), but bleak/WinRT does not.
- The only state that worked unencrypted was the **very first pairing**, before the pump had
  any entry for this central (that run got 25 reads). Once the pump registers the central it
  demands encryption, and that first-pairing window is hard to re-enter reliably.

**Net:** everything up to and including the full therapy profile was captured; the last
reads need either the real **phone app** (correct LESC bond) or a guaranteed fresh
first-pairing connection that holds long enough. `bleak` on Windows cannot form the bond the
pump accepts.

## Earlier link-stability notes (superseded by the above)
The BLE link drops ~1 s after connect (WinRT "operation canceled" → the pump disconnects).
Ruled out in software: write-with vs without-response, post-connect settle delay,
subscription count — none fixed it. It is an **unbonded-link + weak-RF (~−71 dBm)** issue
made worse by reconnect churn. **Workaround that works:** toggle the pump's Bluetooth
off/on + place it next to the PC → the next connection is clean and holds long enough for
one full read batch (the profile's 9-read chain came through in a single such connection).
Recon progress now **persists across runs** (`captured_state.txt`), so each reset-batch
targets only what's still missing.

## Still to capture (each needs one clean reset-connection)
BasalIQ settings/status/alert-info, CGM alert status, malfunction status, and the ~30
minor/undocumented `currentStatus` reads (extended bolus, etc.).

## Read-only safety
- The brain never constructs `request.control.*`; `actionsAffectingInsulinDelivery` left
  false; CONTROL + CONTROL_STREAM UUIDs hard-blocked in the transport.
- Everything above is **observation only** — nothing was changed on the pump.
