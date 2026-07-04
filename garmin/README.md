# bgdude — Garmin Connect IQ companion app

A Connect IQ **widget with glance support** that shows the current BG
(mmol/L), trend arrow, reading age and IOB, pushed from the bgdude Android
app over the free **Connect IQ Mobile SDK** (the same pattern xDrip+ and
GarminHomeAssistant use — no paid Garmin Health API involved).

```
bgdude (Android)                          Garmin watch
PumpService → GarminIntegration           BgDudeApp (this project)
            → GarminSender ──ConnectIQ──▶ Communications.registerForPhoneAppMessages
              sendMessage({bg, trend,     → Storage → widget / glance render
                delta, ageSec, iob, unit,
                battery, reservoir})
```

BG is sent in **mg/dL** and converted on the watch to the display unit
(`unit`): `mmol/L` shows one decimal (mg/dL ÷ 18.0), `mg/dL` shows a whole
number. Range colouring is always computed from the mg/dL value.

- **Glance:** one line — `7.3 → +0.6  IOB 1.4` (BG value, trend arrow, delta,
  IOB), under a small "BGDUDE" title.
- **Widget**, centered top-to-bottom (reads the same on round and rectangular
  screens):
  - unit label (`mmol/L` / `mg/dL`)
  - large **range-coloured** BG value with the trend arrow beside it
    (red < 70 mg/dL, green 70–180, amber > 180)
  - delta + reading age — `+0.6   2m ago`
  - IOB, pump battery (drawn battery icon + `%`, red at ≤ 20 %) and reservoir
    on one bottom line; any piece that is absent is skipped so the face never
    crowds
- The trend arrow is drawn from primitives (shaft + head), so no custom font is
  needed: `↑↑ ↑ ↗ → ↘ ↓ ↓↓` map to
  `doubleUp singleUp fortyFiveUp flat fortyFiveDown singleDown doubleDown`.
- Data older than **15 minutes greys out** and is marked "(stale)".
- Messages are **queued by the Connect IQ framework**: readings sent while
  the widget is closed are delivered the next time the widget or glance
  registers its listener, so the last pushed value shows up on open. The
  received payload is persisted in `Application.Storage`, so the glance
  always has the last-known value even before a fresh message arrives.

> Why a widget and not also a data field? A Connect IQ app has exactly one
> `type` per manifest. A BG **data field** for activity screens would be a
> second, near-identical CIQ project reusing `BgData` — easy to add later.

## 1. Install the Connect IQ SDK

1. Download the **Connect IQ SDK Manager** from
   <https://developer.garmin.com/connect-iq/sdk/> and sign in with a (free)
   Garmin developer account.
2. In the SDK Manager, download the latest SDK and the **device files** for
   your watch (e.g. `fenix7`, `venu3`). Set the downloaded SDK as active.
3. Add the SDK `bin/` directory to your `PATH` so `monkeyc` and
   `monkeydo`/`connectiq` are runnable. (Alternatively use the VS Code
   "Monkey C" extension, which wraps all of this.)

## 2. Generate a developer key

Every CIQ build must be signed with a developer key (RSA-4096, DER):

```bash
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem \
        -out developer_key.der -nocrypt
```

Keep `developer_key.der` out of version control. The VS Code extension can
also generate this via *Monkey C: Generate a Developer Key*.

## 3. Build

From this `garmin/` directory:

```bash
monkeyc -f monkey.jungle \
        -d fenix7 \
        -o bin/bgdude.prg \
        -y /path/to/developer_key.der \
        -w
```

Substitute `-d` with your device id (must be listed in `manifest.xml`;
add your device there if missing). `-w` enables warnings.

To try it in the simulator instead of on hardware:

```bash
connectiq                 # start the simulator
monkeydo bin/bgdude.prg fenix7
```

## 4. Sideload the .prg onto the watch

1. Connect the watch over USB (it mounts as mass storage / MTP).
2. Copy `bin/bgdude.prg` into the watch's `GARMIN/Apps/` directory.
3. Disconnect; the widget appears in the widget/glance list after a
   moment (add it to your glance loop in the watch settings if needed).

Because the app is sideloaded with your own developer key, it does not need
to be published to the Connect IQ store.

## 5. The app UUID — where it is used on the Android side

`manifest.xml` declares the application id:

```
id="33a5cbffcdb94cdfa61c69ec806dec41"
```

This UUID is the address the phone sends messages to. On the Android side it
is hard-coded as `GarminSender.WATCH_APP_UUID` in
`android/app/src/main/kotlin/com/bgdude/app/garmin/GarminSender.kt`, and is
used to construct the `IQApp` handle passed to `ConnectIQ.sendMessage(...)`.
**The two values must match exactly** (32 hex chars, no dashes) or messages
will silently go nowhere.

For a private sideloaded app any UUID works, as long as both sides agree —
this one was generated with a standard UUID generator. If you ever publish
to the Connect IQ store, the store assigns/keeps this manifest UUID as the
app's identity, so keep it stable; if you regenerate it (e.g. via the VS
Code *Monkey C* project wizard), update `GarminSender.WATCH_APP_UUID` to
match.

## Message payload contract

The Android app sends one message per new CGM reading (debounced on the CGM
timestamp). BG and delta are sent in **mg/dL**; the watch converts to the
display unit locally.

| key         | type   | meaning                                                                                               |
|-------------|--------|-------------------------------------------------------------------------------------------------------|
| `bg`        | Number | current glucose in **mg/dL** (e.g. `132`)                                                              |
| `trend`     | String | `doubleUp`, `singleUp`, `fortyFiveUp`, `flat`, `fortyFiveDown`, `singleDown`, `doubleDown`, `unknown`  |
| `delta`     | Number | change in **mg/dL** since the previous reading (may be negative; may be absent)                        |
| `ageSec`    | Number | age of the reading when sent, seconds                                                                  |
| `iob`       | Float  | insulin on board, units (`-1` or absent = unknown)                                                    |
| `unit`      | String | display unit, `"mmol"` or `"mgdl"` (default `"mmol"`)                                                  |
| `battery`   | Number | pump battery percent (optional)                                                                       |
| `reservoir` | Float  | pump reservoir units (optional)                                                                       |

The watch adds elapsed time since receipt to `ageSec` when rendering, and
treats anything over 900 s as stale. Every message is treated as a full
snapshot: a key sent as absent/null clears the previously stored value.

## Prerequisites on the phone

- **Garmin Connect** app installed and paired with the watch (the Connect
  IQ Mobile SDK relays through it in `WIRELESS` mode). If it is missing,
  bgdude logs a warning and simply skips watch sync — nothing crashes.
