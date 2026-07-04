import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! One-line glance: "8.2 <arrow>  6m" (greyed when stale), with a tiny title.
(:glance)
class BgDudeGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.clear();

        var h = dc.getHeight();
        var titleFont = (Graphics has :FONT_GLANCE) ? Graphics.FONT_GLANCE : Graphics.FONT_XTINY;
        var valueFont = (Graphics has :FONT_GLANCE_NUMBER)
            ? Graphics.FONT_GLANCE_NUMBER : Graphics.FONT_SMALL;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h / 4, titleFont, "BGDUDE",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var bg = BgData.bgString();
        var lineY = h * 3 / 4;
        if (bg == null) {
            dc.drawText(0, lineY, valueFont, "--",
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var stale = BgData.isStale();
        dc.setColor(stale ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_WHITE,
            Graphics.COLOR_TRANSPARENT);

        // BG value.
        dc.drawText(0, lineY, valueFont, bg,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var x = dc.getTextWidthInPixels(bg, valueFont);

        // Trend arrow just after the number.
        var arrowSize = h / 4;
        BgData.drawTrendArrow(dc, x + arrowSize, lineY, arrowSize, BgData.trend());
        x += arrowSize * 2 + 4;

        // Age.
        var age = BgData.ageString();
        if (age != null) {
            dc.setColor(stale ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY,
                Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, lineY, titleFont, age,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
