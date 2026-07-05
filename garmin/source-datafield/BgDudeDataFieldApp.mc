import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

//! Entry point for the bgdude **data field** — shows live BG on an activity data screen
//! (e.g. during a run/ride). Registers for phone messages under its own app UUID (see
//! manifest-datafield.xml) and stores each snapshot via the shared BgData module.
class BgDudeDataFieldApp extends Application.AppBase {

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
        return [new BgDudeDataFieldView()];
    }
}
