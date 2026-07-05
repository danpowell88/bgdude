import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

//! Application entry point for the bgdude **widget** (with glance). Registers for messages
//! pushed by the bgdude Android app via the Connect IQ Mobile SDK. Phone app messages are
//! queued by the system, so payloads sent while the widget was closed are delivered as soon
//! as the listener registers.
//!
//! The shared BG state/formatting lives in `source-common/BgData.mc`. (Publishing BG as a
//! system complication for third-party faces is deferred — see COMPLICATIONS.md.)
(:glance)
class BgDudeApp extends Application.AppBase {

    //! Last dictionary received from the phone this session (also persisted to Storage by
    //! BgData.save so the glance has it before the first message).
    var mLastMessage as Dictionary or Null;

    function initialize() {
        AppBase.initialize();
        mLastMessage = null;
    }

    function onStart(state as Dictionary or Null) as Void {
        // Not available in every run context (e.g. some glance environments), so guard with
        // `has` — stored data is still shown either way.
        if (Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
        }
    }

    function onStop(state as Dictionary or Null) as Void {
        if (Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(null);
        }
    }

    //! Message from the phone: {bg, trend, delta, ageSec, iob, unit, battery, reservoir}.
    //! Persist it and force a redraw of whatever view is showing.
    function onPhoneMessage(msg as Communications.PhoneAppMessage) as Void {
        var data = msg.data;
        if (data instanceof Lang.Dictionary) {
            mLastMessage = data;
            BgData.save(data);
            WatchUi.requestUpdate();
        }
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new BgDudeView(), new BgDudeDelegate()];
    }

    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new BgDudeGlanceView()];
    }
}
