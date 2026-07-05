/// User-customisable notification categories: each alert type can be opted in/out,
/// given an importance/intensity, sound/vibration style, and a repeat interval so
/// critical alerts (e.g. an urgent predicted low) re-notify until the situation clears.
///
/// Persisted as JSON in the encrypted key-value store.
library;

/// The kinds of things the app notifies about. Ordered roughly by default severity.
enum NotificationCategory {
  urgentLow,
  predictedLow,
  predictedHigh,
  missedBolus,
  stubbornHigh,
  rescueCarb,
  pumpAlarm,
  reservoirLow,
  connectionLost,
  deviceReminder,
  illnessSuggestion,
  morningSummary,
  reportDigest,
  preBolusTimer,
}

extension NotificationCategoryX on NotificationCategory {
  String get label => switch (this) {
        NotificationCategory.urgentLow => 'Urgent low predicted',
        NotificationCategory.predictedLow => 'Low predicted',
        NotificationCategory.predictedHigh => 'High predicted',
        NotificationCategory.missedBolus => 'Missed bolus',
        NotificationCategory.stubbornHigh => 'Stubborn high / site issue',
        NotificationCategory.rescueCarb => 'Rescue carbs',
        NotificationCategory.pumpAlarm => 'Pump alarms',
        NotificationCategory.reservoirLow => 'Low reservoir',
        NotificationCategory.connectionLost => 'Pump disconnected',
        NotificationCategory.deviceReminder => 'Sensor / site reminders',
        NotificationCategory.illnessSuggestion => 'Illness detected',
        NotificationCategory.morningSummary => 'Morning summary',
        NotificationCategory.reportDigest => 'Weekly report',
        NotificationCategory.preBolusTimer => 'Pre-bolus timer',
      };

  String get description => switch (this) {
        NotificationCategory.urgentLow =>
          'A severe low is predicted soon — highest priority.',
        NotificationCategory.predictedLow => 'A low is predicted within the horizon.',
        NotificationCategory.predictedHigh => 'Glucose is trending high.',
        NotificationCategory.missedBolus =>
          'A meal-sized rise with no bolus logged.',
        NotificationCategory.stubbornHigh =>
          'High for hours with insulin not working — possible site failure.',
        NotificationCategory.rescueCarb => 'Suggested fast carbs when low.',
        NotificationCategory.pumpAlarm =>
          'An alarm/alert is active on the pump.',
        NotificationCategory.reservoirLow =>
          'The insulin reservoir is running low.',
        NotificationCategory.connectionLost =>
          'No pump data for a sustained period.',
        NotificationCategory.deviceReminder =>
          'CGM sensor or infusion site is overdue.',
        NotificationCategory.illnessSuggestion =>
          'Your data looks illness-like.',
        NotificationCategory.morningSummary => 'Your daily briefing.',
        NotificationCategory.reportDigest =>
          'A weekly nudge that your report is ready to review.',
        NotificationCategory.preBolusTimer => 'Time to eat after pre-bolusing.',
      };
}

/// Intensity levels, mapped to Android channel importance / priority in the service.
enum NotifImportance { silent, low, normal, high, urgent }

extension NotifImportanceX on NotifImportance {
  String get label => switch (this) {
        NotifImportance.silent => 'Silent',
        NotifImportance.low => 'Low',
        NotifImportance.normal => 'Normal',
        NotifImportance.high => 'High',
        NotifImportance.urgent => 'Urgent',
      };
}

class CategoryPref {
  const CategoryPref({
    required this.enabled,
    required this.importance,
    required this.vibrate,
    required this.sound,
    required this.repeatMinutes,
  });

  final bool enabled;
  final NotifImportance importance;
  final bool vibrate;
  final bool sound;

  /// Re-notify every N minutes while the condition persists (0 = notify once).
  final int repeatMinutes;

  CategoryPref copyWith({
    bool? enabled,
    NotifImportance? importance,
    bool? vibrate,
    bool? sound,
    int? repeatMinutes,
  }) =>
      CategoryPref(
        enabled: enabled ?? this.enabled,
        importance: importance ?? this.importance,
        vibrate: vibrate ?? this.vibrate,
        sound: sound ?? this.sound,
        repeatMinutes: repeatMinutes ?? this.repeatMinutes,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'importance': importance.name,
        'vibrate': vibrate,
        'sound': sound,
        'repeatMinutes': repeatMinutes,
      };

  factory CategoryPref.fromJson(Map<String, dynamic> j) => CategoryPref(
        enabled: j['enabled'] as bool? ?? true,
        importance: NotifImportance.values.asNameMap()[j['importance']] ??
            NotifImportance.normal,
        vibrate: j['vibrate'] as bool? ?? true,
        sound: j['sound'] as bool? ?? true,
        repeatMinutes: (j['repeatMinutes'] as num?)?.toInt() ?? 0,
      );
}

class NotificationPrefs {
  const NotificationPrefs(this.byCategory);

  final Map<NotificationCategory, CategoryPref> byCategory;

  CategoryPref of(NotificationCategory c) =>
      byCategory[c] ?? _defaultFor(c);

  NotificationPrefs withCategory(NotificationCategory c, CategoryPref pref) =>
      NotificationPrefs({...byCategory, c: pref});

  Map<String, dynamic> toJson() =>
      {for (final e in byCategory.entries) e.key.name: e.value.toJson()};

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) {
    final map = <NotificationCategory, CategoryPref>{};
    for (final c in NotificationCategory.values) {
      final raw = j[c.name];
      map[c] = raw == null
          ? _defaultFor(c)
          : CategoryPref.fromJson((raw as Map).cast<String, dynamic>());
    }
    return NotificationPrefs(map);
  }

  factory NotificationPrefs.defaults() => NotificationPrefs(
        {for (final c in NotificationCategory.values) c: _defaultFor(c)},
      );

  static CategoryPref _defaultFor(NotificationCategory c) => switch (c) {
        NotificationCategory.urgentLow => const CategoryPref(
            enabled: true,
            importance: NotifImportance.urgent,
            vibrate: true,
            sound: true,
            repeatMinutes: 15), // re-alert until it clears
        NotificationCategory.predictedLow => const CategoryPref(
            enabled: true,
            importance: NotifImportance.high,
            vibrate: true,
            sound: true,
            repeatMinutes: 0),
        NotificationCategory.predictedHigh => const CategoryPref(
            enabled: true,
            importance: NotifImportance.normal,
            vibrate: false,
            sound: false,
            repeatMinutes: 0),
        NotificationCategory.missedBolus => const CategoryPref(
            enabled: true,
            importance: NotifImportance.high,
            vibrate: true,
            sound: true,
            repeatMinutes: 0),
        NotificationCategory.stubbornHigh => const CategoryPref(
            enabled: true,
            importance: NotifImportance.normal,
            vibrate: true,
            sound: false,
            repeatMinutes: 0),
        NotificationCategory.rescueCarb => const CategoryPref(
            enabled: true,
            importance: NotifImportance.high,
            vibrate: true,
            sound: true,
            repeatMinutes: 0),
        NotificationCategory.pumpAlarm => const CategoryPref(
            enabled: true,
            importance: NotifImportance.high,
            vibrate: true,
            sound: true,
            repeatMinutes: 0),
        NotificationCategory.reservoirLow => const CategoryPref(
            enabled: true,
            importance: NotifImportance.normal,
            vibrate: true,
            sound: false,
            repeatMinutes: 0),
        NotificationCategory.connectionLost => const CategoryPref(
            enabled: true,
            importance: NotifImportance.normal,
            vibrate: false,
            sound: false,
            repeatMinutes: 0),
        NotificationCategory.deviceReminder => const CategoryPref(
            enabled: true,
            importance: NotifImportance.low,
            vibrate: false,
            sound: false,
            repeatMinutes: 0),
        NotificationCategory.illnessSuggestion => const CategoryPref(
            enabled: true,
            importance: NotifImportance.low,
            vibrate: false,
            sound: false,
            repeatMinutes: 0),
        NotificationCategory.morningSummary => const CategoryPref(
            enabled: true,
            importance: NotifImportance.normal,
            vibrate: false,
            sound: true,
            repeatMinutes: 0),
        NotificationCategory.reportDigest => const CategoryPref(
            enabled: true,
            importance: NotifImportance.low,
            vibrate: false,
            sound: false,
            repeatMinutes: 0),
        NotificationCategory.preBolusTimer => const CategoryPref(
            enabled: true,
            importance: NotifImportance.high,
            vibrate: true,
            sound: true,
            repeatMinutes: 0),
      };
}
