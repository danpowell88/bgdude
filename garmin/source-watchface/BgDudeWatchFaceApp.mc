import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

//! Entry point for the bgdude **watch face**. Like the widget it registers for phone
//! messages (its own app UUID — see manifest-watchface.xml) and stores each snapshot via
//! the shared BgData module, so the face shows the last-known reading immediately and
//! updates live as the phone pushes new ones. It also publishes the BG complication.
class BgDudeWatchFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary or Null) as Void {
        if (Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
        }
        BgComplication.register();
    }

    function onStop(state as Dictionary or Null) as Void {
        if (Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(null);
        }
    }

    function onPhoneMessage(msg as Communications.PhoneAppMessage) as Void {
        var data = msg.data;
        if (data instanceof Lang.Dictionary) {
            BgData.save(data);
            BgComplication.publish();
            WatchUi.requestUpdate();
        }
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new BgDudeWatchFaceView()];
    }
}
