import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Entry point for the bgdude **watch face**. All of the background-registration lifecycle
//! lives in [BgBackgroundApp] (source-common); this only supplies the face view. A watch
//! face cannot receive phone messages in the foreground, so it relies on the background
//! phone-app-message event the base registers for. (Complications are published only by the
//! widget/app build — publishing is not permitted from a watch face.)
class BgDudeWatchFaceApp extends BgBackgroundApp {

    function initialize() {
        BgBackgroundApp.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new BgDudeWatchFaceView()];
    }
}
