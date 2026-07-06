import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Shared entry-point base for the background-driven bgdude products (the watch face and the
//! data field). Neither can receive phone messages in the foreground, so both register for
//! the phone-app-message *background* event and hand the framework a [BgServiceDelegate]
//! that stores each snapshot; the view reads it from Application.Storage on redraw. This
//! base owns that identical lifecycle so a fix to the background-registration logic is made
//! once, not per product (TASK-112). Subclasses supply only getInitialView().
//!
//! Lives in source-service (with BgServiceDelegate) rather than source-common: the widget
//! build does not include source-service and does not use the background lifecycle, so
//! keeping the base here avoids compiling a BgServiceDelegate reference into the widget.
class BgBackgroundApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    //! Wake a background service whenever the phone pushes a reading.
    function onStart(state as Dictionary or Null) as Void {
        if (Toybox has :Background &&
                (Background has :registerForPhoneAppMessageEvent)) {
            Background.registerForPhoneAppMessageEvent();
        }
    }

    function onStop(state as Dictionary or Null) as Void {
    }

    //! The framework asks for the background worker that handles the phone-message event.
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new BgServiceDelegate()];
    }

    //! The background finished with a fresh payload while we're on screen — redraw now
    //! (otherwise the product picks it up on its next scheduled update).
    function onBackgroundData(data as Application.PersistableType) as Void {
        WatchUi.requestUpdate();
    }
}
