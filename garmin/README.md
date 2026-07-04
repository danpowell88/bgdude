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
                ageSec, iob, unit})
```

- **Glance:** one line — BG value, trend arrow, minutes-ago.
- **Widget:** large BG value, trend arrow, unit, "Xm ago", IOB.
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
timestamp):

| key      | type   | meaning                                   |
|----------|--------|-------------------------------------------|
| `bg`     | Float  | BG in mmol/L, already converted from mg/dL |
| `trend`  | String | `doubleUp`, `singleUp`, `fortyFiveUp`, `flat`, `fortyFiveDown`, `singleDown`, `doubleDown`, `unknown` |
| `ageSec` | Number | age of the reading when sent, seconds      |
| `iob`    | Float  | insulin on board, units (may be absent)    |
| `unit`   | String | display unit label, `"mmol/L"`             |

The watch adds elapsed time since receipt to `ageSec` when rendering, and
treats anything over 900 s as stale.

## Prerequisites on the phone

- **Garmin Connect** app installed and paired with the watch (the Connect
  IQ Mobile SDK relays through it in `WIRELESS` mode). If it is missing,
  bgdude logs a warning and simply skips watch sync — nothing crashes.
