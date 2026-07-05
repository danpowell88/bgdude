import Toybox.System;
import Toybox.Lang;
import Toybox.Application;
import Toybox.Communications;
import Toybox.Background;
import Toybox.Time;

//! Background service that receives the phone→watch BG push for the **watch face** and
//! **data field**. Those app types cannot call `Communications.registerForPhoneAppMessages`
//! in the foreground (it's restricted to widgets/apps/background), so instead their App
//! registers for the phone-app-message background event and the system wakes this delegate
//! when a message arrives. We persist the snapshot to `Application.Storage` — the same keys
//! BgData reads — and exit; the view picks it up on its next redraw.
//!
//! Runs in the background scope, so it only touches Storage/Time (no Graphics).
(:background)
class BgServiceDelegate extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onPhoneAppMessage(msg as Communications.PhoneAppMessage) as Void {
        var d = msg.data;
        if (d instanceof Lang.Dictionary) {
            // Keys mirror BgData.KEY_* (kept as literals so this stays in the background
            // scope without pulling BgData's Graphics-using drawing code in).
            Storage.setValue("bg", d["bg"]);
            Storage.setValue("trend", d["trend"]);
            Storage.setValue("delta", d["delta"]);
            Storage.setValue("ageSec", d["ageSec"]);
            Storage.setValue("iob", d["iob"]);
            Storage.setValue("unit", d["unit"]);
            Storage.setValue("battery", d["battery"]);
            Storage.setValue("reservoir", d["reservoir"]);
            Storage.setValue("receivedAt", Time.now().value());
        }
        // Hand the payload back so a running foreground view can redraw immediately.
        Background.exit(d);
    }
}
