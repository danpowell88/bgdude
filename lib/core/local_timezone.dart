/// TASK-175: point `tz.local` at the device's real timezone. `initializeTimeZones()`
/// alone leaves `tz.local` at UTC, so every wall-clock schedule (the 07:00 morning
/// summary, the weekly report nudge) silently fired offset by the UTC delta — 17:00
/// in AEST. Call this once per isolate that schedules notifications, right after
/// `tzdata.initializeTimeZones()`.
library;

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

import '../logging/app_log.dart';

Future<void> configureLocalTimezone() async {
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (e) {
    // Schedules degrade to UTC rather than crashing; loud in the log.
    appLog.error('tz', 'device timezone resolve failed — schedules stay in UTC',
        error: e);
  }
}
