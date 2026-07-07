/// Global test harness hook (TASK-172): flutter_test discovers this file and
/// routes every test main() through [testExecutable].
///
/// KvStore is all-static with a shared memory map, so isolation used to rely on
/// each file remembering `setUp(KvStore.useMemory)` — isolation by convention
/// fails silently. The global setUp resets the store before EVERY test, killing
/// the whole order-dependent-state bug class.
library;

import 'dart:async';

import 'package:bgdude/data/kv_store.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(KvStore.useMemory);
  await testMain();
}
