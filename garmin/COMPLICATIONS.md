# bgdude BG complication

`source-common/BgComplication.mc` publishes the current glucose as a **system
Complication** (Connect IQ **4.1.0+**), so any watch face — including
third-party faces — can display the bgdude reading by picking it in the face's
complication slot, without that face needing its own phone link.

## How it works

- Each product (widget, watch face, data field) calls `BgComplication.register()`
  once in `onStart`, then `BgComplication.publish()` on every phone message.
- `register()` sets up a change-callback so the system can ask us to refresh;
  `publish()` pushes the current value + `BG` / `Blood Glucose` labels + unit.
- Everything is guarded by `Toybox has :Complications`, so on watches older than
  CIQ 4.1.0 the calls are no-ops (the widget/watch face/data field still work).

To display it: on a watch face that supports Connect IQ complications, edit the
face and choose **bgdude** for a data slot.

## Enabling / disabling

It is on by default (the three entry points call it). To build **without**
complications — e.g. if your installed SDK errors on the publisher API — remove
the two `BgComplication.register()` / `BgComplication.publish()` lines from each
`source-*/BgDude*App.mc`, or delete `source-common/BgComplication.mc` and its
calls. Nothing else depends on it.

## SDK note

The Complications *publisher* API (`Complications.Complication`,
`Complications.Id`, `Complications.updateComplication`,
`registerComplicationChangeCallback`) landed in SDK 4.1.0. This module targets
that API; if your installed SDK's signatures differ, the only file that needs
adjusting is `BgComplication.mc` — align the field/method names with your SDK's
`Toybox.Complications` reference. Compile it in the simulator to confirm before
sideloading.
