import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;

//! Shared BG state + drawing helpers, reused by every bgdude Connect IQ product type
//! (widget, glance, watch face, data field). Kept in `source-common` and referenced from
//! each product's jungle so there is a single source of truth for the payload contract,
//! unit handling, range colouring and the primitive-drawn trend arrow / battery icon.
//!
//! Annotated (:glance) so it can be pulled into the low-memory glance scope of the widget.
//!
//! The payload pushed from the phone is a Dictionary. BG is always sent in mg/dL as a whole
//! Number; the watch converts to the display unit locally. See save() for the full key list.
//!   { "bg" => Number (mg/dL), "trend" => String, "delta" => Number (mg/dL),
//!     "ageSec" => Number, "iob" => Float (units, -1/absent = unknown),
//!     "unit" => "mmol"|"mgdl", "battery" => Number, "reservoir" => Float }
(:glance)
module BgData {
    const KEY_BG = "bg";
    const KEY_TREND = "trend";
    const KEY_DELTA = "delta";
    const KEY_AGE_SEC = "ageSec";
    const KEY_IOB = "iob";
    const KEY_UNIT = "unit";
    const KEY_BATTERY = "battery";
    const KEY_RESERVOIR = "reservoir";
    const KEY_RECEIVED_AT = "receivedAt"; // epoch seconds, stamped on the watch

    const STALE_AFTER_SEC = 900; // 15 minutes
    const MMOL_PER_MGDL = 18.0;  // divide mg/dL by this to get mmol/L

    // Range thresholds, always evaluated in mg/dL regardless of display unit.
    const LOW_MGDL = 70;
    const HIGH_MGDL = 180;

    //! Persist a payload received from the phone. Every message is a full snapshot, so
    //! absent keys store null and clear any previous value (e.g. a pump that stops
    //! reporting battery no longer shows a stale percentage).
    function save(data as Dictionary) as Void {
        Storage.setValue(KEY_BG, data[KEY_BG]);
        Storage.setValue(KEY_TREND, data[KEY_TREND]);
        Storage.setValue(KEY_DELTA, data[KEY_DELTA]);
        Storage.setValue(KEY_AGE_SEC, data[KEY_AGE_SEC]);
        Storage.setValue(KEY_IOB, data[KEY_IOB]);
        Storage.setValue(KEY_UNIT, data[KEY_UNIT]);
        Storage.setValue(KEY_BATTERY, data[KEY_BATTERY]);
        Storage.setValue(KEY_RESERVOIR, data[KEY_RESERVOIR]);
        Storage.setValue(KEY_RECEIVED_AT, Time.now().value());
    }

    //! Raw glucose in mg/dL as a whole Number, or null if no data yet.
    function bgMgdl() as Number or Null {
        var bg = Storage.getValue(KEY_BG);
        if (!(bg instanceof Lang.Number) && !(bg instanceof Lang.Float)) {
            return null;
        }
        return (bg as Numeric).toNumber();
    }

    //! Display unit, normalised to "mmol" or "mgdl" (default "mmol").
    function rawUnit() as String {
        var u = Storage.getValue(KEY_UNIT);
        if ((u instanceof Lang.String) && u.equals("mgdl")) {
            return "mgdl";
        }
        return "mmol";
    }

    //! Human-readable unit label for the face ("mmol/L" / "mg/dL").
    function unitLabel() as String {
        return rawUnit().equals("mgdl") ? "mg/dL" : "mmol/L";
    }

    //! BG formatted for display: "8.2" for mmol/L (1 decimal), "148" for mg/dL (whole
    //! number), or null when there is no reading yet.
    function bgDisplayString() as String or Null {
        var mgdl = bgMgdl();
        if (mgdl == null) {
            return null;
        }
        if (rawUnit().equals("mgdl")) {
            return mgdl.format("%d");
        }
        return (mgdl.toFloat() / MMOL_PER_MGDL).format("%.1f");
    }

    //! Range colour for the BG value, computed from mg/dL thresholds:
    //! red < 70, green 70-180, amber > 180.
    function bgColor() as Graphics.ColorType {
        var mgdl = bgMgdl();
        if (mgdl == null) {
            return Graphics.COLOR_WHITE;
        }
        if (mgdl < LOW_MGDL) {
            return Graphics.COLOR_RED;
        }
        if (mgdl > HIGH_MGDL) {
            return Graphics.COLOR_ORANGE;
        }
        return Graphics.COLOR_GREEN;
    }

    function trend() as String {
        var t = Storage.getValue(KEY_TREND);
        return (t instanceof Lang.String) ? t : "unknown";
    }

    //! Signed change since the previous reading, in the display unit:
    //! "+0.6" / "-1.2" (mmol) or "+11" / "-20" (mg/dL). Null when unknown.
    function deltaString() as String or Null {
        var d = Storage.getValue(KEY_DELTA);
        if (!(d instanceof Lang.Number) && !(d instanceof Lang.Float)) {
            return null;
        }
        if (rawUnit().equals("mgdl")) {
            var v = (d as Numeric).toNumber();
            var sign = (v < 0) ? "-" : "+";
            if (v < 0) { v = -v; }
            return sign + v.format("%d");
        }
        var f = (d as Numeric).toFloat() / MMOL_PER_MGDL;
        var fsign = (f < 0) ? "-" : "+";
        if (f < 0) { f = -f; }
        return fsign + f.format("%.1f");
    }

    //! "IOB 1.4U" or null when the pump did not report IOB (-1 or absent).
    function iobString() as String or Null {
        var f = iobValue();
        if (f == null) {
            return null;
        }
        return "IOB " + f.format("%.1f") + "U";
    }

    //! Shorter "IOB 1.4" (no unit suffix) for the tight glance line.
    function iobShort() as String or Null {
        var f = iobValue();
        if (f == null) {
            return null;
        }
        return "IOB " + f.format("%.1f");
    }

    //! IOB in units as a Float, or null if unknown (-1 or absent).
    function iobValue() as Float or Null {
        var iob = Storage.getValue(KEY_IOB);
        if (!(iob instanceof Lang.Number) && !(iob instanceof Lang.Float)) {
            return null;
        }
        var f = (iob as Numeric).toFloat();
        if (f < 0) {
            return null;
        }
        return f;
    }

    //! Pump battery percent, or null when not reported.
    function battery() as Number or Null {
        var b = Storage.getValue(KEY_BATTERY);
        if (!(b instanceof Lang.Number) && !(b instanceof Lang.Float)) {
            return null;
        }
        return (b as Numeric).toNumber();
    }

    //! Reservoir label "142U", or null when not reported.
    function reservoirString() as String or Null {
        var r = Storage.getValue(KEY_RESERVOIR);
        if (!(r instanceof Lang.Number) && !(r instanceof Lang.Float)) {
            return null;
        }
        var f = (r as Numeric).toFloat();
        if (f < 0) {
            return null;
        }
        return f.format("%.0f") + "U";
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

    //! Draw the trend arrow at (x, y) (arrow center), self-contained polygon drawing so no
    //! custom font is required. `size` is the arrow length in px.
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

    //! Small battery glyph: outline + terminal nub + charge-proportional fill.
    //! (x, y) is the left edge / vertical center; w, h are the body size. Drawn with
    //! primitives so no emoji/custom font is required.
    function drawBatteryIcon(dc as Graphics.Dc, x as Number, y as Number,
                             w as Number, h as Number, pct as Number,
                             color as Graphics.ColorType) as Void {
        var top = y - h / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(x, top, w, h);
        // Terminal nub on the right.
        dc.fillRectangle(x + w, top + h / 4, 2, h - h / 2);
        // Charge fill.
        var inner = w - 2;
        var fillW = inner * pct / 100;
        if (fillW < 0) { fillW = 0; }
        if (fillW > inner) { fillW = inner; }
        dc.fillRectangle(x + 1, top + 1, fillW, h - 2);
    }
}
