import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/units.dart';
import '../insights/alert_thresholds.dart';
import '../insights/notification_prefs.dart';
import '../state/providers.dart';

/// Per-category notification controls: opt in/out, importance, sound/vibration, and a
/// repeat interval so critical alerts re-notify until the situation clears.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    final notifier = ref.read(notificationPrefsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'These alerts are additive to your CGM/pump alarms — they never replace '
              'them. Tune each category below.',
            ),
          ),
          const _ThresholdsCard(),
          const _QuietHoursCard(),
          const Divider(),
          for (final c in NotificationCategory.values)
            _CategoryTile(
              category: c,
              pref: prefs.of(c),
              onChanged: (p) => notifier.setCategory(c, p),
            ),
        ],
      ),
    );
  }
}

class _ThresholdsCard extends ConsumerWidget {
  const _ThresholdsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(glucoseUnitProvider);
    final t = ref.watch(alertThresholdsProvider);
    final notifier = ref.read(alertThresholdsProvider.notifier);
    String g(double mgdl) => '${Mgdl(mgdl).display(unit)} ${unit.label}';

    Widget stepper(String label, double value, ValueChanged<double> onSet,
            double min, double max) =>
        Row(
          children: [
            Expanded(child: Text(label)),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed:
                  value - 5 >= min ? () => onSet(value - 5) : null,
            ),
            SizedBox(width: 78, child: Text(g(value), textAlign: TextAlign.center)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: value + 5 <= max ? () => onSet(value + 5) : null,
            ),
          ],
        );

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alert thresholds',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            stepper('Low alert', t.lowMgdl,
                (v) => notifier.save(t.copyWith(lowMgdl: v)), 60, 110),
            stepper('High alert', t.highMgdl,
                (v) => notifier.save(t.copyWith(highMgdl: v)), 140, 300),
            Text('Predicted-low/high nudges use these. Safety modifiers (age, alcohol, '
                'exercise) can only make the low alert lead earlier.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            _SegmentOverride(
              title: 'Overnight (23:00–07:00)',
              subtitle: 'Warn earlier while you sleep.',
              segment: AlertSegment.overnight,
              thresholds: t,
              stepper: stepper,
              onSave: notifier.save,
            ),
            _SegmentOverride(
              title: 'Post-meal (first 2h after carbs)',
              subtitle: 'Tolerate the expected bump so you\'re not nagged.',
              segment: AlertSegment.postMeal,
              thresholds: t,
              stepper: stepper,
              onSave: notifier.save,
            ),
          ],
        ),
      ),
    );
  }
}

/// One collapsible per-time-of-day override row (§4-2.3). Off ⇒ the all-day thresholds
/// apply. On ⇒ its low/high replace them for that segment (urgent-low stays the all-day
/// value — it's a single safety line). Toggling on seeds from the current all-day row.
class _SegmentOverride extends StatelessWidget {
  const _SegmentOverride({
    required this.title,
    required this.subtitle,
    required this.segment,
    required this.thresholds,
    required this.stepper,
    required this.onSave,
  });

  final String title;
  final String subtitle;
  final AlertSegment segment;
  final AlertThresholds thresholds;
  final Widget Function(
      String label, double value, ValueChanged<double> onSet, double min, double max) stepper;
  final void Function(AlertThresholds) onSave;

  @override
  Widget build(BuildContext context) {
    final band = thresholds.segments[segment];
    final on = band != null;
    final effective = band ?? thresholds.allDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(title),
          subtitle: Text(subtitle),
          value: on,
          onChanged: (v) => onSave(v
              ? thresholds.withSegment(segment, thresholds.allDay)
              : thresholds.withoutSegment(segment)),
        ),
        if (on) ...[
          stepper('Low alert', effective.lowMgdl,
              (v) => onSave(thresholds.withSegment(segment, effective.copyWith(lowMgdl: v))), 60, 110),
          stepper('High alert', effective.highMgdl,
              (v) => onSave(thresholds.withSegment(segment, effective.copyWith(highMgdl: v))), 140, 300),
        ],
      ],
    );
  }
}

class _QuietHoursCard extends ConsumerWidget {
  const _QuietHoursCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    final notifier = ref.read(notificationPrefsProvider.notifier);
    final q = prefs.quietHours;
    String hhmm(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

    Future<void> pick(bool start) async {
      final initial = start ? q.startMinute : q.endMinute;
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      );
      if (picked == null) return;
      final m = picked.hour * 60 + picked.minute;
      await notifier.setQuietHours(
          start ? q.copyWith(startMinute: m) : q.copyWith(endMinute: m));
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Quiet hours'),
              subtitle: const Text(
                  'Hold back non-critical alerts overnight. Urgent lows and pump '
                  'alarms always come through.'),
              value: q.enabled,
              onChanged: (v) => notifier.setQuietHours(q.copyWith(enabled: v)),
            ),
            if (q.enabled)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => pick(true),
                      child: Text('From ${hhmm(q.startMinute)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => pick(false),
                      child: Text('To ${hhmm(q.endMinute)}'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.pref,
    required this.onChanged,
  });

  final NotificationCategory category;
  final CategoryPref pref;
  final ValueChanged<CategoryPref> onChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(category.label),
      subtitle: Text(pref.enabled
          ? '${pref.importance.label}'
              '${pref.repeatMinutes > 0 ? ' · repeats every ${pref.repeatMinutes}m' : ''}'
          : 'Off'),
      leading: Switch(
        value: pref.enabled,
        onChanged: (v) => onChanged(pref.copyWith(enabled: v)),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        Text(category.description,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Intensity'),
            const Spacer(),
            DropdownButton<NotifImportance>(
              value: pref.importance,
              onChanged: pref.enabled
                  ? (v) => onChanged(pref.copyWith(importance: v))
                  : null,
              items: [
                for (final i in NotifImportance.values)
                  DropdownMenuItem<NotifImportance>(
                      value: i, child: Text(i.label)),
              ],
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Sound'),
          value: pref.sound,
          onChanged:
              pref.enabled ? (v) => onChanged(pref.copyWith(sound: v)) : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Vibrate'),
          value: pref.vibrate,
          onChanged:
              pref.enabled ? (v) => onChanged(pref.copyWith(vibrate: v)) : null,
        ),
        Row(
          children: [
            const Text('Repeat until clear'),
            const Spacer(),
            DropdownButton<int>(
              value: pref.repeatMinutes,
              onChanged: pref.enabled
                  ? (v) => onChanged(pref.copyWith(repeatMinutes: v))
                  : null,
              // Always include the current value (categories default to 15 or 60, and a
              // persisted custom value could be anything) so the dropdown never asserts.
              items: [
                for (final m in {0, 5, 15, 30, 60, pref.repeatMinutes}.toList()
                  ..sort())
                  DropdownMenuItem(
                      value: m, child: Text(m == 0 ? 'Once' : 'Every ${m}m')),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
