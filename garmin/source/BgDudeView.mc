import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Full widget view: large BG (mmol/L) with trend arrow, reading age and IOB.
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

        var bg = BgData.bgString();
        if (bg == null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_MEDIUM, "bgdude\nwaiting for phone...",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var stale = BgData.isStale();
        var mainColor = stale ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_WHITE;
        var subColor = stale ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY;

        // Large BG value, slightly above center.
        var bgFont = Graphics.FONT_NUMBER_THAI_HOT;
        var bgY = h * 42 / 100;
        dc.setColor(mainColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, bgY, bgFont, bg,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Trend arrow to the right of the number.
        var bgWidth = dc.getTextWidthInPixels(bg, bgFont);
        var arrowSize = h / 8;
        BgData.drawTrendArrow(dc, cx + bgWidth / 2 + arrowSize, bgY, arrowSize,
            BgData.trend());

        // Unit label above the number.
        dc.setColor(subColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 16 / 100, Graphics.FONT_XTINY, BgData.unitString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Age line ("6m ago", flagged when stale).
        var age = BgData.ageString();
        var ageLabel = (age == null) ? "--" : (age + " ago" + (stale ? " (stale)" : ""));
        dc.drawText(cx, h * 66 / 100, Graphics.FONT_SMALL, ageLabel,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // IOB line.
        var iob = BgData.iobString();
        if (iob != null) {
            dc.drawText(cx, h * 80 / 100, Graphics.FONT_SMALL, iob,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
