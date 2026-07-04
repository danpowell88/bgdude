import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.WatchUi;

//! Shared state + drawing helpers, usable from both the widget view and the
//! glance view (hence the (:glance) annotation).
(:glance)
module BgData {
    // Storage keys. The payload pushed from the phone is a Dictionary:
    //   { "bg" => Float (mmol/L), "trend" => String, "ageSec" => Number,
    //     "iob" => Float (units, optional), "unit" => String }
    const KEY_BG = "bg";
    const KEY_TREND = "trend";
    const KEY_AGE_SEC = "ageSec";
    const KEY_IOB = "iob";
    const KEY_UNIT = "unit";
    const KEY_RECEIVED_AT = "receivedAt"; // epoch seconds, stamped on the watch

    const STALE_AFTER_SEC = 900; // 15 minutes

    //! Persist a payload received from the phone.
    function save(data as Dictionary) as Void {
        Storage.setValue(KEY_BG, data[KEY_BG]);
        Storage.setValue(KEY_TREND, data[KEY_TREND]);
        Storage.setValue(KEY_AGE_SEC, data[KEY_AGE_SEC]);
        Storage.setValue(KEY_IOB, data[KEY_IOB]);
        Storage.setValue(KEY_UNIT, data[KEY_UNIT]);
        Storage.setValue(KEY_RECEIVED_AT, Time.now().value());
    }

    //! BG formatted to one decimal ("8.2"), or null if no data yet.
    function bgString() as String or Null {
        var bg = Storage.getValue(KEY_BG);
        if (bg == null) {
            return null;
        }
        if (bg instanceof Lang.String) {
            return bg;
        }
        return (bg as Numeric).toFloat().format("%.1f");
    }

    function trend() as String {
        var t = Storage.getValue(KEY_TREND);
        return (t instanceof Lang.String) ? t : "unknown";
    }

    function unitString() as String {
        var u = Storage.getValue(KEY_UNIT);
        return (u instanceof Lang.String) ? u : "mmol/L";
    }

    //! "IOB 1.2u" or null when the pump didn't report IOB.
    function iobString() as String or Null {
        var iob = Storage.getValue(KEY_IOB);
        if (iob == null) {
            return null;
        }
        return "IOB " + (iob as Numeric).toFloat().format("%.1f") + "u";
    }

    //! Total age of the reading in seconds: age when sent + time since receipt.
    function ageSeconds() as Number or Null {
        var receivedAt = Storage.getValue(KEY_RECEIVED_AT);
        if (receivedAt == null) {
            return null;
        }
        var ageAtSend = Storage.getValue(KEY_AGE_SEC);
        var base = (ageAtSend == null) ? 0 : (ageAtSend as Numeric).toNumber();
        var elapsed = Time.now().value() - (receivedAt as Number);
        if (elapsed < 0) {
            elapsed = 0;
        }
        return base + elapsed;
    }

    //! "3m" style age label, or null if no data yet.
    function ageString() as String or Null {
        var age = ageSeconds();
        if (age == null) {
            return null;
        }
        var mins = age / 60;
        if (mins > 99) {
            mins = 99;
        }
        return mins.format("%d") + "m";
    }

    function isStale() as Boolean {
        var age = ageSeconds();
        return (age == null) || (age > STALE_AFTER_SEC);
    }

    //! Draw the trend arrow at (x, y) (arrow center), self-contained polygon
    //! drawing so no custom font is required. `size` is the arrow length in px.
    function drawTrendArrow(dc as Graphics.Dc, x as Number, y as Number,
                            size as Number, trendName as String) as Void {
        var angleDeg = null; // 0 = right, 90 = up
        var doubled = false;
        if (trendName.equals("doubleUp")) { angleDeg = 90; doubled = true; }
        else if (trendName.equals("singleUp")) { angleDeg = 90; }
        else if (trendName.equals("fortyFiveUp")) { angleDeg = 45; }
        else if (trendName.equals("flat")) { angleDeg = 0; }
        else if (trendName.equals("fortyFiveDown")) { angleDeg = -45; }
        else if (trendName.equals("singleDown")) { angleDeg = -90; }
        else if (trendName.equals("doubleDown")) { angleDeg = -90; doubled = true; }
        if (angleDeg == null) {
            return; // unknown trend: draw nothing
        }
        if (doubled) {
            // Two vertical arrows side by side.
            _drawOneArrow(dc, x - size / 2 - 1, y, size, angleDeg);
            _drawOneArrow(dc, x + size / 2 + 1, y, size, angleDeg);
        } else {
            _drawOneArrow(dc, x, y, size, angleDeg);
        }
    }

    //! One arrow: a shaft line plus a triangular head, rotated to angleDeg.
    function _drawOneArrow(dc as Graphics.Dc, x as Number, y as Number,
                           size as Number, angleDeg as Number) as Void {
        var rad = angleDeg * Math.PI / 180.0;
        var cosA = Math.cos(rad);
        var sinA = Math.sin(rad);
        var half = size / 2;
        // Screen y grows downward, so "up" subtracts sin.
        var tipX = x + (half * cosA).toNumber();
        var tipY = y - (half * sinA).toNumber();
        var tailX = x - (half * cosA).toNumber();
        var tailY = y + (half * sinA).toNumber();
        var headLen = size / 2;
        var headHalfW = size / 3;
        // Head base center sits headLen behind the tip along the shaft.
        var baseX = tipX - (headLen * cosA).toNumber();
        var baseY = tipY + (headLen * sinA).toNumber();
        // Perpendicular unit vector.
        var pX = -sinA;
        var pY = -cosA;
        dc.setPenWidth(size > 14 ? 3 : 2);
        dc.drawLine(tailX, tailY, baseX, baseY);
        dc.fillPolygon([
            [tipX, tipY],
            [baseX + (headHalfW * pX).toNumber(), baseY + (headHalfW * pY).toNumber()],
            [baseX - (headHalfW * pX).toNumber(), baseY - (headHalfW * pY).toNumber()],
        ]);
        dc.setPenWidth(1);
    }
}

//! Application entry point. Registers for messages pushed by the bgdude
//! Android app via the Connect IQ Mobile SDK. Phone app messages are queued
//! by the system, so payloads sent while the widget was closed are delivered
//! as soon as the listener registers.
(:glance)
class BgDudeApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary or Null) as Void {
        // Not available in every run context (e.g. some glance environments),
        // so guard with `has` — stored data is still shown either way.
        if (Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
        }
    }

    function onStop(state as Dictionary or Null) as Void {
        if (Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(null);
        }
    }

    //! Message from the phone: {bg, trend, ageSec, iob, unit}.
    function onPhoneMessage(msg as Communications.PhoneAppMessage) as Void {
        var data = msg.data;
        if (data instanceof Lang.Dictionary) {
            BgData.save(data);
            WatchUi.requestUpdate();
        }
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new BgDudeView(), new BgDudeDelegate()];
    }

    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or Null {
        return [new BgDudeGlanceView()];
    }
}
