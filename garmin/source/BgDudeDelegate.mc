import Toybox.Lang;
import Toybox.WatchUi;

//! Input delegate for the widget view. The widget is display-only; a select
//! press just forces a redraw so the age line refreshes immediately.
class BgDudeDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        WatchUi.requestUpdate();
        return true;
    }
}
