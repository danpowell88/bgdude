import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
