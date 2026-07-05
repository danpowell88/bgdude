import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Entry point for the bgdude **watch face**. A watch face cannot receive phone messages in
//! the foreground, so it registers for the phone-app-message *background* event and a
//! [BgServiceDelegate] (source-common) stores each snapshot; the face reads it from
//! Application.Storage on redraw. (Complications are published only by the widget/app
//! build — publishing is not permitted from a watch face.)
class BgDudeWatchFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary or Null) as Void {
        // Wake a background service whenever the phone pushes a reading.
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
    //! (otherwise the face picks it up on its next scheduled update).
    function onBackgroundData(data as Application.PersistableType) as Void {
        WatchUi.requestUpdate();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new BgDudeWatchFaceView()];
    }
}
