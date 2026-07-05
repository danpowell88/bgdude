import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/units.dart';
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
          ],
        ),
      ),
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
              items: const [
                DropdownMenuItem(value: 0, child: Text('Once')),
                DropdownMenuItem(value: 5, child: Text('Every 5m')),
                DropdownMenuItem(value: 15, child: Text('Every 15m')),
                DropdownMenuItem(value: 30, child: Text('Every 30m')),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
