import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! One-line glance: "7.3 <arrow> +0.6  IOB 1.4" (greyed when stale), under a
//! tiny "BGDUDE" title. The BG value is range-coloured like the widget.
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

        var bg = BgData.bgDisplayString();
        var lineY = h * 3 / 4;
        if (bg == null) {
            dc.drawText(0, lineY, valueFont, "--",
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var stale = BgData.isStale();
        var valueColor = stale ? Graphics.COLOR_DK_GRAY : BgData.bgColor();
        var subColor = stale ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY;

        // BG value.
        var x = 0;
        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, lineY, valueFont, bg,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += dc.getTextWidthInPixels(bg, valueFont) + 2;

        // Trend arrow just after the number.
        var arrowSize = h / 4;
        BgData.drawTrendArrow(dc, x + arrowSize, lineY, arrowSize, BgData.trend());
        x += arrowSize * 2 + 6;

        // Delta.
        var delta = BgData.deltaString();
        if (delta != null) {
            dc.setColor(subColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, lineY, titleFont, delta,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            x += dc.getTextWidthInPixels(delta, titleFont) + 8;
        }

        // IOB (compact, no unit suffix) if it still fits.
        var iob = BgData.iobShort();
        if (iob != null) {
            dc.setColor(subColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, lineY, titleFont, iob,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
