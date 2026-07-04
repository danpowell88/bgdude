// Driver for the screenshot capture pipeline. Run with:
//   flutter drive --driver=test_driver/screenshot_driver.dart \
//     --target=integration_test/screenshots_test.dart -d <device>
//
// Each `binding.takeScreenshot(name)` in the target test streams PNG bytes here, which
// we write to doc/screenshots/<name>.png. See tools/gen_docs.ps1 / gen_docs.sh.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final dir = Directory('doc/screenshots');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File('doc/screenshots/$name.png').writeAsBytesSync(bytes);
      stdout.writeln('captured doc/screenshots/$name.png (${bytes.length} bytes)');
      return true;
    },
  );
}
