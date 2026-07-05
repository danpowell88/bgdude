import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! bgdude data field for activity screens. Draws the current BG **range-coloured**
//! (red < 70 / green in-range / amber > 180 mg/dL) with the trend arrow beside it, scaling
//! the font to whatever field size the user placed it in (works as a 1-, 2- or half-screen
//! field). Greys out and appends "!" once the reading is stale (>15 min).
//!
//! Custom DataField (not SimpleDataField) so the value can be coloured — colour is the
//! whole point of a glucose field. No activity metric is computed; the value comes from the
//! phone via BgData.
class BgDudeDataFieldView extends WatchUi.DataField {

    function initialize() {
        DataField.initialize();
    }

    //! No activity-derived metric; BG arrives via phone messages. Kept so the framework has
    //! a compute() to call.
    function compute(info as Toybox.Activity.Info) as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var bgColor = getBackgroundColor();
        var fg = (bgColor == Graphics.COLOR_BLACK)
            ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(fg, bgColor);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        // Tiny "BG" label top-left so a glance identifies the field.
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(3, 1, Graphics.FONT_XTINY, "BG",
            Graphics.TEXT_JUSTIFY_LEFT);

        var bg = BgData.bgDisplayString();
        if (bg == null) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_MEDIUM, "--",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var stale = BgData.isStale();
        var valueColor = stale ? Graphics.COLOR_DK_GRAY : BgData.bgColor();
        // On a light field background, keep in-range green readable by darkening white.
        if (!stale && bgColor != Graphics.COLOR_BLACK
                && valueColor == Graphics.COLOR_GREEN) {
            valueColor = Graphics.COLOR_DK_GREEN;
        }

        var font = pickFont(dc, bg, w, h);
        var bgWidth = dc.getTextWidthInPixels(bg, font);
        var arrowSize = h / 6;
        if (arrowSize < 8) { arrowSize = 8; }
        var groupW = bgWidth + arrowSize * 2 + 4;
        var startX = cx - groupW / 2;
        if (startX < 2) { startX = 2; }

        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, cy, font, bg,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        BgData.drawTrendArrow(dc, startX + bgWidth + arrowSize + 2, cy, arrowSize,
            BgData.trend());

        if (stale) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 3, 1, Graphics.FONT_XTINY, "!",
                Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }

    //! Largest number font whose text fits the field width (and roughly its height).
    function pickFont(dc as Graphics.Dc, text as String, w as Number, h as Number)
            as Graphics.FontDefinition {
        var fonts = [
            Graphics.FONT_NUMBER_THAI_HOT,
            Graphics.FONT_NUMBER_HOT,
            Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_MILD,
            Graphics.FONT_LARGE,
            Graphics.FONT_MEDIUM,
            Graphics.FONT_SMALL,
        ];
        var budgetW = w * 55 / 100; // leave room for the arrow
        for (var i = 0; i < fonts.size(); i += 1) {
            var f = fonts[i];
            if (dc.getTextWidthInPixels(text, f) <= budgetW
                    && dc.getFontHeight(f) <= h) {
                return f;
            }
        }
        return Graphics.FONT_SMALL;
    }
}
