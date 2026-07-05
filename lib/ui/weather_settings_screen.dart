import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Set a city for ambient-weather context. Heat/cold nudges the low-alert threshold and
/// weather is correlated against daily glucose. Opt-in — nothing is fetched until a city
/// is set. Uses Open-Meteo (free, no key); only the city/coords leave the device.
class WeatherSettingsScreen extends ConsumerStatefulWidget {
  const WeatherSettingsScreen({super.key});
  @override
  ConsumerState<WeatherSettingsScreen> createState() =>
      _WeatherSettingsScreenState();
}

class _WeatherSettingsScreenState extends ConsumerState<WeatherSettingsScreen> {
  late final TextEditingController _city =
      TextEditingController(text: ref.read(weatherSettingsProvider).city);
  bool _busy = false;

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _setCity() async {
    final name = _city.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final loc = await ref.read(weatherServiceProvider).geocode(name);
      if (loc == null) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Could not find that place.')));
        return;
      }
      await ref.read(weatherSettingsProvider.notifier).save(
            ref.read(weatherSettingsProvider).copyWith(
                enabled: true, city: loc.name, lat: loc.lat, lon: loc.lon),
          );
      ref.invalidate(weatherProvider);
      messenger.showSnackBar(SnackBar(content: Text('Weather set to ${loc.name}.')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Weather lookup failed.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(weatherSettingsProvider);
    final weather = ref.watch(weatherProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Weather')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hot weather speeds insulin absorption (more hypos); cold has a paradoxical '
            'risk. With a city set, low alerts lead a little earlier at temperature '
            'extremes, and weather is correlated against your glucose.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use weather'),
            value: settings.enabled,
            onChanged: (v) => ref
                .read(weatherSettingsProvider.notifier)
                .save(settings.copyWith(enabled: v)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _city,
            decoration: InputDecoration(
              labelText: 'City / town',
              hintText: 'e.g. Sydney',
              suffixIcon: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(icon: const Icon(Icons.search), onPressed: _setCity),
            ),
            onSubmitted: (_) => _setCity(),
          ),
          const SizedBox(height: 16),
          if (weather != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.thermostat),
                title: Text('${weather.tempC.toStringAsFixed(1)} °C'
                    '${weather.humidity != null ? ' · ${weather.humidity!.round()}% humidity' : ''}'),
                subtitle: Text(settings.city),
              ),
            ),
          const SizedBox(height: 12),
          Text('Weather data by Open-Meteo (CC BY 4.0).',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
