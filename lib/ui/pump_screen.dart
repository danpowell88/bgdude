import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/insulin_totals.dart';
import '../core/samples.dart';
import '../core/units.dart';
import '../logging/device_changes.dart';
import '../pump/pump_events.dart';
import '../pump/pump_snapshot.dart';
import '../state/providers.dart';

/// Read-only view of everything we sync from the pump: live status, insulin totals,
/// reservoir runway, site age, active alarms/alerts, and a recent-events timeline.
class PumpScreen extends ConsumerWidget {
  const PumpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(pumpSnapshotProvider).valueOrNull;
    final unit = ref.watch(glucoseUnitProvider);
    final totals = ref.watch(insulinTodayProvider);
    final devices = ref.watch(deviceStateProvider);
    final events = ref.watch(pumpEventsProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Pump')),
      body: snap == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No pump data yet. Connect your pump or turn on dev '
                    'mode to explore with a simulated t:slim X2.'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (snap.activeAlarms.isNotEmpty || snap.activeAlerts.isNotEmpty)
                  _AlertsCard(
                      alarms: snap.activeAlarms, alerts: snap.activeAlerts),
                _StatusCard(snap: snap, unit: unit),
                _InsulinTodayCard(totals: totals),
                _ReservoirCard(snap: snap),
                _SiteCard(devices: devices, now: now),
                _DeviceCard(snap: snap),
                events.when(
                  data: (list) => _EventsCard(events: list),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.color});
  final String title;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.snap, required this.unit});
  final PumpSnapshot snap;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context) {
    final cgm = snap.cgmMgdl;
    return _Section(
      title: 'Live status',
      child: Column(
        children: [
          if (cgm != null)
            _Row(
              'Glucose',
              '${Mgdl(cgm.toDouble()).display(unit)} ${unit.label} '
                  '${(snap.cgmTrend ?? GlucoseTrend.unknown).arrow}',
              emphasize: true,
            ),
          _Row('Insulin on board',
              snap.iobUnits == null ? '—' : '${snap.iobUnits!.toStringAsFixed(2)} U'),
          _Row(
              'Basal rate',
              snap.basalUnitsPerHour == null
                  ? '—'
                  : '${snap.basalUnitsPerHour!.toStringAsFixed(2)} U/hr'),
          _Row('Control-IQ', _controlIqLabel(snap)),
          if (snap.lastBolusUnits != null)
            _Row('Last bolus',
                '${snap.lastBolusUnits!.toStringAsFixed(2)} U · ${_ago(snap.lastBolusTime)}'),
          if (snap.maxBolusUnits != null)
            _Row('Max bolus', '${snap.maxBolusUnits!.toStringAsFixed(1)} U'),
          if (snap.maxBasalUnitsPerHour != null)
            _Row('Max basal', '${snap.maxBasalUnitsPerHour!.toStringAsFixed(2)} U/hr'),
        ],
      ),
    );
  }


  /// "Off", "Active", or "Active · Sleep" — the mode annotates the on state so the user
  /// sees which target band the loop is steering to.
  static String _controlIqLabel(PumpSnapshot snap) {
    final on = snap.closedLoopEnabled ?? snap.controlIqActive ?? false;
    if (!on) return 'Off';
    final mode = snap.controlIqMode;
    return mode == ControlIqMode.unknown ? 'Active' : 'Active · ${mode.label}';
  }
}

class _InsulinTodayCard extends StatelessWidget {
  const _InsulinTodayCard({required this.totals});
  final InsulinTotals totals;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Insulin today',
      child: Column(
        children: [
          _Row('Total', '${totals.total.toStringAsFixed(1)} U', emphasize: true),
          _Row('Bolus', '${totals.bolus.toStringAsFixed(1)} U'),
          _Row('Basal', '${totals.basal.toStringAsFixed(1)} U'),
          _Row('Basal share', '${(totals.basalFraction * 100).round()}%'),
        ],
      ),
    );
  }
}

class _ReservoirCard extends StatelessWidget {
  const _ReservoirCard({required this.snap});
  final PumpSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final r = snap.reservoirUnits;
    final rate = snap.basalUnitsPerHour;
    final low = r != null && r <= 15;
    String runway = '';
    if (r != null && rate != null && rate > 0) {
      final hours = r / rate;
      runway = ' · ~${hours.toStringAsFixed(0)} h at current basal';
    }
    return _Section(
      title: 'Reservoir',
      color: low ? Theme.of(context).colorScheme.errorContainer : null,
      child: _Row('Insulin left', r == null ? '—' : '${r.toStringAsFixed(0)} U$runway',
          emphasize: true),
    );
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({required this.devices, required this.now});
  final DeviceState devices;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    String ageText(DeviceKind k) {
      final age = devices.age(k, now);
      if (age == null) return 'Not logged';
      final overdue = devices.isOverdue(k, now);
      final days = age.inHours / 24;
      return '${days.toStringAsFixed(1)} days${overdue ? ' · overdue' : ''}';
    }

    return _Section(
      title: 'Site & sensor',
      child: Column(
        children: [
          _Row('Infusion site', ageText(DeviceKind.site)),
          _Row('CGM sensor', ageText(DeviceKind.sensor)),
        ],
      ),
    );
  }
}

class _DeviceCard extends ConsumerWidget {
  const _DeviceCard({required this.snap});
  final PumpSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final battery = snap.batteryPercent == null ? '—' : '${snap.batteryPercent}%';
    final drain = ref.watch(batteryDrainProvider).valueOrNull;
    final String batteryDetail;
    if (snap.isCharging == true) {
      batteryDetail = '$battery · charging';
    } else if (drain != null && drain.hasEstimate && drain.timeToEmpty != null) {
      batteryDetail = '$battery · ~${_hrs(drain.timeToEmpty!)} left';
    } else {
      batteryDetail = battery;
    }
    return _Section(
      title: 'Device',
      child: Column(
        children: [
          _Row('Battery', batteryDetail),
          _Row('Firmware', snap.firmwareVersion ?? '—'),
          _Row('API version', snap.apiVersion ?? '—'),
          _Row('Updated', _ago(snap.time)),
        ],
      ),
    );
  }

  static String _hrs(Duration d) {
    final h = d.inMinutes / 60.0;
    return h < 1 ? '${d.inMinutes}m' : '${h.toStringAsFixed(h < 3 ? 1 : 0)}h';
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.alarms, required this.alerts});
  final List<String> alarms;
  final List<String> alerts;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Section(
      title: 'Active on pump',
      color: alarms.isNotEmpty ? cs.errorContainer : cs.tertiaryContainer,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final a in alarms)
            Chip(
              avatar: const Icon(Icons.error_outline, size: 18),
              label: Text(_humanize(a)),
            ),
          for (final a in alerts)
            Chip(
              avatar: const Icon(Icons.info_outline, size: 18),
              label: Text(_humanize(a)),
            ),
        ],
      ),
    );
  }
}

class _EventsCard extends StatelessWidget {
  const _EventsCard({required this.events});
  final List<PumpEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final shown = events.take(20).toList();
    return _Section(
      title: 'Recent pump events',
      child: Column(
        children: [
          for (final e in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(_icon(e.kind), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${e.kind.label}: ${_humanize(e.detail)}')),
                  Text(_ago(e.time),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static IconData _icon(PumpEventKind k) => switch (k) {
        PumpEventKind.alarm => Icons.error_outline,
        PumpEventKind.alert => Icons.info_outline,
        PumpEventKind.cartridgeChange => Icons.battery_charging_full,
        PumpEventKind.cannulaChange => Icons.healing,
      };
}

String _humanize(String raw) {
  final words = raw
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w.length <= 3 && w.toUpperCase() == w
          ? w // keep acronyms (CGM, IOB)
          : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .toList();
  return words.isEmpty ? raw : words.join(' ');
}

String _ago(DateTime? t) {
  if (t == null) return '—';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
