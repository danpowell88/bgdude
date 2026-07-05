import Toybox.Complications;
import Toybox.Lang;

//! Publishes the current BG as a system **Complication** (Connect IQ 4.1.0+), so any watch
//! face — including third-party faces — can display the bgdude reading without its own phone
//! link. Each product (widget, watch face, data field) calls [register] once on start and
//! [publish] whenever a fresh reading arrives.
//!
//! Everything is guarded by `Toybox has :Complications` (older watches simply skip it) and
//! wrapped in try/catch so a Complications API hiccup can never destabilise the view.
//!
//! NOTE: The Complications publisher API arrived in SDK 4.1.0. If your installed SDK's
//! signatures differ, any compile error is isolated to THIS file — adjust the field/method
//! names per your SDK's `Toybox.Complications` docs, or remove the two `BgComplication`
//! calls in the app/watch-face/data-field entry points to build without it. See
//! COMPLICATIONS.md.
(:glance)
module BgComplication {

    //! Stable custom sub-id for our single "Blood Glucose" complication.
    const SUB_ID = 42;

    var _id as Complications.Id or Null = null;

    //! Register once so the complication appears in the system picker and the watch can ask
    //! us to refresh it. Safe to call from onStart of any product.
    function register() as Void {
        if (!(Toybox has :Complications)) {
            return;
        }
        try {
            _id = new Complications.Id(SUB_ID);
            Complications.registerComplicationChangeCallback(
                new Lang.Method(BgComplication, :onUpdateRequested));
            publish();
        } catch (e) {
            _id = null;
        }
    }

    //! Push the latest BG value/label to subscribers.
    function publish() as Void {
        if (!(Toybox has :Complications)) {
            return;
        }
        try {
            var id = (_id != null) ? _id : new Complications.Id(SUB_ID);
            var comp = new Complications.Complication(id);
            comp.shortLabel = "BG";
            comp.longLabel = "Blood Glucose";
            comp.unit = BgData.unitLabel();
            var disp = BgData.bgDisplayString();
            comp.value = (disp == null) ? "--" : disp;
            Complications.updateComplication(comp);
        } catch (e) {
        }
    }

    //! The system asks us to refresh (a face subscribed / woke). Re-publish current data.
    function onUpdateRequested(id as Complications.Id) as Void {
        publish();
    }
}
