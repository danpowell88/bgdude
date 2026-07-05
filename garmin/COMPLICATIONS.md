# bgdude BG complication — deferred

Publishing the current glucose as a **system Complication** (so any watch face —
including third-party faces — could show the bgdude reading in a complication
slot, without its own phone link) is **not implemented**. The three products
(widget, watch face, data field) each display BG directly instead.

## Why it was removed

An earlier attempt (`source-common/BgComplication.mc`) built the complication at
runtime — `new Complications.Id(42)`, `new Complications.Complication(id)`,
setting `comp.value` / `comp.shortLabel`, and `registerComplicationChangeCallback`.
That does not match the Connect IQ API and does not compile:

- `Complications.Id` takes a `Complications.Type`, not an arbitrary `Number`.
- `registerComplicationChangeCallback` is a **subscriber** API and needs the
  `ComplicationSubscriber` permission — it's for a *face reading* complications,
  not an app publishing one.
- Publishing is only valid for `app`/`widget` product types, so calling it from
  the watch-face / data-field builds fails outright.

## The correct approach (if revisited)

Connect IQ's publisher API is `Complications.updateComplication(index, data)`
(SDK **4.2.0+**), which updates an **application complication defined in a
resource file**, not one constructed at runtime:

1. Define the complication in `resources/` (an `<iq:complications>` / complication
   resource with an id, type and boundary).
2. Add the `ComplicationPublisher` permission to `manifest.xml` (the widget/app
   only — watch faces and data fields cannot publish).
3. From the widget app, call `Complications.updateComplication(index,
   new Complications.Data(...))` whenever a fresh reading arrives.
4. Verify on-device with a face that subscribes to Connect IQ complications
   (the simulator can't fully exercise the publish→subscribe path).

It was left out rather than shipped broken; the watch face already surfaces BG
prominently, which covers most of the "glance at my glucose" need.
