import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Full widget view. Layout, top to bottom, centered so it reads the same on
//! round and rectangular screens:
//!   * unit label ("mmol/L" / "mg/dL")
//!   * large range-coloured BG value with the trend arrow beside it
//!   * delta + reading age ("+0.6   2m ago")
//!   * IOB and pump battery (+ reservoir) on one bottom line
//! Everything greys out once the reading is older than 15 minutes so a stale
//! number is never mistaken for a live one.
class BgDudeView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        var bg = BgData.bgDisplayString();
        if (bg == null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_MEDIUM, "bgdude\nwaiting for phone...",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var stale = BgData.isStale();
        var subColor = stale ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY;
        var valueColor = stale ? Graphics.COLOR_DK_GRAY : BgData.bgColor();

        // Unit label, top.
        dc.setColor(subColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 15 / 100, Graphics.FONT_XTINY, BgData.unitLabel(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Large BG value, above center, range-coloured.
        var bgFont = Graphics.FONT_NUMBER_THAI_HOT;
        var bgY = h * 40 / 100;
        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, bgY, bgFont, bg,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Trend arrow to the right of the number, same colour.
        var bgWidth = dc.getTextWidthInPixels(bg, bgFont);
        var arrowSize = h / 9;
        BgData.drawTrendArrow(dc, cx + bgWidth / 2 + arrowSize, bgY, arrowSize,
            BgData.trend());

        // Delta + age line, e.g. "+0.6   2m ago".
        var mid = midLine(stale);
        if (!mid.equals("")) {
            dc.setColor(subColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 62 / 100, Graphics.FONT_SMALL, mid,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Bottom line: IOB + battery (+ reservoir), centered as a group. Any
        // missing piece is simply skipped so the face never crowds.
        drawBottomLine(dc, cx, h * 80 / 100, subColor, stale);
    }

    //! Compose the "delta   age" secondary line, omitting whichever is absent.
    function midLine(stale as Boolean) as String {
        var delta = BgData.deltaString();
        var age = BgData.ageString();
        var line = (delta == null) ? "" : delta;
        if (age != null) {
            var ageLbl = age + " ago" + (stale ? " (stale)" : "");
            line = line.equals("") ? ageLbl : (line + "   " + ageLbl);
        }
        return line;
    }

    //! Draw IOB, battery and reservoir as a single centered row. Each segment
    //! is measured so the whole group stays centered no matter which are shown.
    function drawBottomLine(dc as Graphics.Dc, cx as Number, y as Number,
                            subColor as Graphics.ColorType, stale as Boolean) as Void {
        var font = Graphics.FONT_TINY;
        var iob = BgData.iobString();
        var battPct = BgData.battery();
        var res = BgData.reservoirString();

        var gap = 12;
        var fh = dc.getFontHeight(font);
        var iconW = fh * 9 / 10;
        var iconH = fh / 2;

        var iobW = (iob == null) ? 0 : dc.getTextWidthInPixels(iob, font);
        var battW = 0;
        if (battPct != null) {
            var s = battPct.format("%d") + "%";
            battW = iconW + 3 + dc.getTextWidthInPixels(s, font);
        }
        var resW = (res == null) ? 0 : dc.getTextWidthInPixels(res, font);

        var total = 0;
        var count = 0;
        if (iobW > 0) { total += iobW; count += 1; }
        if (battW > 0) { total += battW; count += 1; }
        if (resW > 0) { total += resW; count += 1; }
        if (count == 0) {
            return;
        }
        total += gap * (count - 1);

        var x = cx - total / 2;

        if (iob != null) {
            dc.setColor(subColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, font, iob,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            x += iobW + gap;
        }
        if (battPct != null) {
            var battColor = stale ? Graphics.COLOR_DK_GRAY
                : (battPct <= 20 ? Graphics.COLOR_RED : subColor);
            BgData.drawBatteryIcon(dc, x, y, iconW, iconH, battPct, battColor);
            var s = battPct.format("%d") + "%";
            dc.setColor(battColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + iconW + 3, y, font, s,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            x += battW + gap;
        }
        if (res != null) {
            dc.setColor(subColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, font, res,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            x += resW + gap;
        }
    }
}
