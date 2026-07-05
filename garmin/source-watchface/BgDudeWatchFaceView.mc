import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! bgdude watch face. Layout, top to bottom (centered so it reads the same on round and
//! rectangular screens):
//!   * time (HH:MM), large
//!   * date ("Sat 5 Jul"), small
//!   * range-coloured BG value with the trend arrow + delta beside it
//!   * IOB + reading age
//! The BG block greys out once the reading is older than 15 min so a stale number is never
//! mistaken for a live one. In low-power (sleep) mode we still draw the last BG but skip the
//! per-second work — the face only needs the minute + BG, both cheap.
class BgDudeWatchFaceView extends WatchUi.WatchFace {

    var mLowPower as Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onEnterSleep() as Void { mLowPower = true; }
    function onExitSleep() as Void { mLowPower = false; }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        // --- Time (HH:MM) ---
        var clock = System.getClockTime();
        var is24 = System.getDeviceSettings().is24Hour;
        var hour = clock.hour;
        if (!is24) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var timeStr = hour.format("%02d") + ":" + clock.min.format("%02d");
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 26 / 100, Graphics.FONT_NUMBER_MEDIUM, timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- Date ---
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateStr = info.day_of_week + " " + info.day.format("%d") + " " + info.month;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 44 / 100, Graphics.FONT_TINY, dateStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- BG block ---
        var bg = BgData.bgDisplayString();
        var bgY = h * 64 / 100;
        if (bg == null) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, bgY, Graphics.FONT_SMALL, "bgdude —",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var stale = BgData.isStale();
        var valueColor = stale ? Graphics.COLOR_DK_GRAY : BgData.bgColor();
        var subColor = stale ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY;

        var bgFont = Graphics.FONT_NUMBER_MEDIUM;
        var bgWidth = dc.getTextWidthInPixels(bg, bgFont);
        var arrowSize = h / 12;
        // Center the (value + arrow) group.
        var groupW = bgWidth + arrowSize * 2 + 4;
        var startX = cx - groupW / 2;
        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, bgY, bgFont, bg,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        BgData.drawTrendArrow(dc, startX + bgWidth + arrowSize + 2, bgY, arrowSize,
            BgData.trend());

        // --- delta + IOB + age line ---
        var parts = "";
        var delta = BgData.deltaString();
        if (delta != null) { parts = delta; }
        var iob = BgData.iobShort();
        if (iob != null) { parts = parts.equals("") ? iob : (parts + "  " + iob); }
        var age = BgData.ageString();
        if (age != null) {
            var ageLbl = age + (stale ? " (stale)" : "");
            parts = parts.equals("") ? ageLbl : (parts + "  " + ageLbl);
        }
        if (!parts.equals("")) {
            dc.setColor(subColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 82 / 100, Graphics.FONT_XTINY, parts,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
