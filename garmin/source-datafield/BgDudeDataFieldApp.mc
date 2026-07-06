import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Entry point for the bgdude **data field** — shows live BG on an activity data screen. All
//! of the background-registration lifecycle lives in [BgBackgroundApp] (source-common); this
//! only supplies the field view. A data field cannot receive phone messages in the
//! foreground, so it relies on the background phone-app-message event the base registers for.
//! (Complications are published only by the widget/app build.)
class BgDudeDataFieldApp extends BgBackgroundApp {

    function initialize() {
        BgBackgroundApp.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new BgDudeDataFieldView()];
    }
}
