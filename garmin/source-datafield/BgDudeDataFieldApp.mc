import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Entry point for the bgdude **data field** — shows live BG on an activity data screen
//! (e.g. during a run/ride). A data field cannot receive phone messages in the foreground,
//! so it registers for the phone-app-message *background* event and a [BgServiceDelegate]
//! (source-common) stores each snapshot; the field reads it from Application.Storage when it
//! recomputes. (Complications are published only by the widget/app build.)
class BgDudeDataFieldApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary or Null) as Void {
        if (Toybox has :Background &&
                (Background has :registerForPhoneAppMessageEvent)) {
            Background.registerForPhoneAppMessageEvent();
        }
    }

    function onStop(state as Dictionary or Null) as Void {
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new BgServiceDelegate()];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        WatchUi.requestUpdate();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new BgDudeDataFieldView()];
    }
}
