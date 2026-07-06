import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;

//! Functional tests for the shared BgData logic (formatting, unit conversion, range colour,
//! delta sign, IOB, staleness), run in the Connect IQ **simulator** via the unit-test
//! runner. These are the pieces every product type (widget, watch face, data field) relies
//! on, so testing them once covers all four.
//!
//! Build + run (from garmin/):
//!   monkeyc -f test.jungle -d fenix7 --unit-test -o bin/test.prg -y developer_key.der
//!   monkeydo bin/test.prg fenix7 -t
//! or use garmin/tools/run_tests.ps1 / .sh. See README "Functional tests".

//! Persist a full snapshot the way the phone would, then let BgData read it back.
function seed(bg as Number or Null, unit as String, trend as String,
             delta as Object or Null, iob as Object or Null,
             battery as Object or Null, reservoir as Object or Null) as Void {
    Storage.clearValues();
    BgData.save({
        "bg" => bg,
        "unit" => unit,
        "trend" => trend,
        "delta" => delta,
        "ageSec" => 0,
        "iob" => iob,
        "battery" => battery,
        "reservoir" => reservoir,
    });
}

(:test)
function testBgDisplayMmol(logger as Test.Logger) as Boolean {
    seed(132, "mmol", "flat", null, null, null, null);
    Test.assertEqualMessage(BgData.bgDisplayString(), "7.3", "132 mg/dL → 7.3 mmol/L");
    Test.assertEqualMessage(BgData.unitLabel(), "mmol/L", "unit label");
    return true;
}

(:test)
function testBgDisplayMgdl(logger as Test.Logger) as Boolean {
    seed(148, "mgdl", "flat", null, null, null, null);
    Test.assertEqualMessage(BgData.bgDisplayString(), "148", "148 mg/dL whole number");
    Test.assertEqualMessage(BgData.unitLabel(), "mg/dL", "unit label");
    return true;
}

(:test)
function testNoDataIsNull(logger as Test.Logger) as Boolean {
    Storage.clearValues();
    Test.assertEqual(BgData.bgDisplayString(), null);
    Test.assertEqual(BgData.deltaString(), null);
    Test.assert(BgData.isStale()); // no data counts as stale
    return true;
}

(:test)
function testRangeColour(logger as Test.Logger) as Boolean {
    seed(65, "mmol", "flat", null, null, null, null);
    Test.assertEqualMessage(BgData.bgColor(), Graphics.COLOR_RED, "65 mg/dL is low → red");
    seed(120, "mmol", "flat", null, null, null, null);
    Test.assertEqualMessage(BgData.bgColor(), Graphics.COLOR_GREEN, "120 in range → green");
    seed(210, "mmol", "flat", null, null, null, null);
    Test.assertEqualMessage(BgData.bgColor(), Graphics.COLOR_ORANGE, "210 high → amber");
    return true;
}

(:test)
function testDeltaMmol(logger as Test.Logger) as Boolean {
    seed(132, "mmol", "flat", 11, null, null, null);
    Test.assertEqualMessage(BgData.deltaString(), "+0.6", "+11 mg/dL → +0.6 mmol/L");
    seed(132, "mmol", "flat", -20, null, null, null);
    Test.assertEqualMessage(BgData.deltaString(), "-1.1", "-20 mg/dL → -1.1 mmol/L");
    return true;
}

(:test)
function testDeltaMgdl(logger as Test.Logger) as Boolean {
    seed(132, "mgdl", "flat", 11, null, null, null);
    Test.assertEqualMessage(BgData.deltaString(), "+11", "+11 mg/dL whole");
    seed(132, "mgdl", "flat", -20, null, null, null);
    Test.assertEqualMessage(BgData.deltaString(), "-20", "-20 mg/dL whole");
    return true;
}

(:test)
function testIob(logger as Test.Logger) as Boolean {
    seed(132, "mmol", "flat", null, 1.4, null, null);
    Test.assertEqualMessage(BgData.iobString(), "IOB 1.4U", "iob string");
    Test.assertEqualMessage(BgData.iobShort(), "IOB 1.4", "iob short");
    seed(132, "mmol", "flat", null, -1, null, null);
    Test.assertEqualMessage(BgData.iobString(), null, "-1 means unknown IOB");
    return true;
}

(:test)
function testBatteryAndReservoir(logger as Test.Logger) as Boolean {
    seed(132, "mmol", "flat", null, null, 78, 142.0);
    Test.assertEqual(BgData.battery(), 78);
    Test.assertEqualMessage(BgData.reservoirString(), "142U", "reservoir label");
    seed(132, "mmol", "flat", null, null, null, null);
    Test.assertEqual(BgData.battery(), null);
    Test.assertEqual(BgData.reservoirString(), null);
    return true;
}

(:test)
function testTrend(logger as Test.Logger) as Boolean {
    seed(132, "mmol", "singleUp", null, null, null, null);
    Test.assertEqual(BgData.trend(), "singleUp");
    Storage.clearValues();
    Test.assertEqualMessage(BgData.trend(), "unknown", "missing trend defaults to unknown");
    return true;
}

(:test)
function testStaleness(logger as Test.Logger) as Boolean {
    seed(132, "mmol", "flat", null, null, null, null); // stamps receivedAt = now
    Test.assertMessage(!BgData.isStale(), "a just-received reading is fresh");
    // Backdate receipt beyond the 15-min window.
    Storage.setValue(BgData.KEY_RECEIVED_AT, Time.now().value() - 1000);
    Storage.setValue(BgData.KEY_AGE_SEC, 0);
    Test.assertMessage(BgData.isStale(), "a 1000s-old reading is stale");
    return true;
}
