# bgdude — Garmin Connect IQ companion

Connect IQ products that show the current BG (mmol/L or mg/dL), trend arrow,
delta, reading age and IOB, pushed from the bgdude Android app over the free
**Connect IQ Mobile SDK** (the same pattern xDrip+ and GarminHomeAssistant use
— no paid Garmin Health API involved). Four product types, all sharing one
`source-common/BgData.mc` module so unit handling, range colouring and the
primitive-drawn trend arrow are defined once:

| Product        | type        | manifest / jungle                         | shows |
|----------------|-------------|-------------------------------------------|-------|
| **Widget** (+ glance) | `widget`    | `manifest.xml` / `monkey.jungle`          | full BG panel + one-line glance |
| **Watch face** | `watchface` | `manifest-watchface.xml` / `watchface.jungle` | time + date + BG/trend/IOB |
| **Data field** | `datafield` | `manifest-datafield.xml` / `datafield.jungle` | range-coloured BG on activity screens |
| **Complication** | (published) | `source-common/BgComplication.mc`         | BG as a system complication any face can show (CIQ 4.1+) — see [COMPLICATIONS.md](COMPLICATIONS.md) |

A Connect IQ app has exactly one `type` per manifest, so the widget, watch face
and data field are three builds/`.prg`s sharing `source-common`; each registers
for phone messages under its own UUID (all three are listed on the Android side,
see below) and additionally publishes the BG complication.

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

The **watch face** shows the time and date with a range-coloured BG line
(value + trend arrow + delta + IOB/age), greying out when stale, and drops the
per-second work in low-power mode. The **data field** shows BG range-coloured on
an activity data screen, scaling the font to whatever field size you place it in.

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

From this `garmin/` directory, build whichever product(s) you want — each has
its own jungle:

```bash
monkeyc -f monkey.jungle    -d fenix7 -o bin/bgdude.prg            -y developer_key.der -w  # widget
monkeyc -f watchface.jungle -d fenix7 -o bin/bgdude-watchface.prg  -y developer_key.der -w  # watch face
monkeyc -f datafield.jungle -d fenix7 -o bin/bgdude-datafield.prg  -y developer_key.der -w  # data field
```

Or build all three at once:

```bash
powershell -File tools/build_all.ps1 -Device fenix7    # Windows
```

Substitute `-d` with your device id (must be listed in the matching
`manifest*.xml`; add your device there if missing). `-w` enables warnings.

To try a product in the simulator instead of on hardware:

```bash
connectiq                              # start the simulator
monkeydo bin/bgdude-watchface.prg fenix7
```

## Functional tests (simulator)

`tests/BgDataTest.mc` holds `(:test)` unit tests for the shared `BgData` logic
(unit conversion, range colour, delta sign, IOB, staleness) — the code every
product relies on. Build the test target and run it in the simulator:

```bash
monkeyc -f test.jungle -d fenix7 --unit-test -o bin/test.prg -y developer_key.der
monkeydo bin/test.prg fenix7 -t        # -t runs the (:test) functions and prints PASS/FAIL
```

Or use the wrapper (builds, starts the simulator if needed, runs `-t`):

```bash
powershell -File tools/run_tests.ps1 -Device fenix7   # Windows
tools/run_tests.sh fenix7                              # macOS/Linux
```

## 4. Sideload the .prg onto the watch

1. Connect the watch over USB (it mounts as mass storage / MTP).
2. Copy the `.prg`(s) you built into the watch's `GARMIN/Apps/` directory.
3. Disconnect; the widget/watch face/data field appears in its respective list
   after a moment (add the widget to your glance loop, pick the watch face in
   *Watch Face* settings, or add the data field to an activity data screen).

Because the app is sideloaded with your own developer key, it does not need
to be published to the Connect IQ store.

## 5. The app UUIDs — where they are used on the Android side

Each product's manifest declares its own application id, and each is addressed
independently by the phone. On the Android side they are hard-coded in
`android/app/src/main/kotlin/com/bgdude/app/garmin/GarminSender.kt` and the phone
sends every reading to all three (whichever the user installed receives it):

| product    | manifest                  | Android constant           | UUID |
|------------|---------------------------|----------------------------|------|
| widget     | `manifest.xml`            | `WATCH_APP_UUID`           | `33a5cbffcdb94cdfa61c69ec806dec41` |
| watch face | `manifest-watchface.xml`  | `WATCH_FACE_UUID`          | `5b464f4e38a24b0591aaac277b12f3d3` |
| data field | `manifest-datafield.xml`  | `DATA_FIELD_UUID`          | `9306b7b1a5d148888b64c900377a5951` |

**Each pair must match exactly** (32 hex chars, no dashes) or that product's
messages silently go nowhere.

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
