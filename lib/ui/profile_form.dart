import 'package:flutter/material.dart';

import '../profile/user_profile.dart';

/// A reusable profile editor. Emits an updated [UserProfile] via [onChanged] on every
/// edit; the parent decides when to persist. Used in onboarding and in Settings.
class ProfileForm extends StatefulWidget {
  const ProfileForm({super.key, required this.initial, required this.onChanged});

  final UserProfile initial;
  final ValueChanged<UserProfile> onChanged;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _duration;
  late final TextEditingController _weight;
  late final TextEditingController _height;
  late BiologicalSex _sex;
  late DiabetesType _type;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    final now = DateTime.now();
    _name = TextEditingController(text: p.name);
    _age = TextEditingController(text: p.ageAt(now)?.toString() ?? '');
    _duration = TextEditingController(
        text: p.diabetesDurationYears(now)?.toString() ?? '');
    _weight = TextEditingController(text: p.weightKg?.toStringAsFixed(0) ?? '');
    _height = TextEditingController(text: p.heightCm?.toStringAsFixed(0) ?? '');
    _sex = p.sex;
    _type = p.diabetesType;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _duration.dispose();
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  void _emit() {
    final year = DateTime.now().year;
    final age = int.tryParse(_age.text);
    final dur = int.tryParse(_duration.text);
    widget.onChanged(UserProfile(
      name: _name.text.trim(),
      sex: _sex,
      birthYear: age == null ? null : year - age,
      diagnosisYear: dur == null ? null : year - dur,
      weightKg: double.tryParse(_weight.text),
      heightCm: double.tryParse(_height.text),
      diabetesType: _type,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Name (optional)'),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<BiologicalSex>(
          initialValue: _sex,
          decoration: const InputDecoration(labelText: 'Sex'),
          items: [
            for (final s in BiologicalSex.values)
              DropdownMenuItem(value: s, child: Text(s.label)),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _sex = v);
            _emit();
          },
        ),
        const SizedBox(height: 4),
        Text('Used to tailor menstrual-cycle insights (female only).',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        DropdownButtonFormField<DiabetesType>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Diabetes type'),
          items: [
            for (final t in DiabetesType.values)
              DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _type = v);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _age,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age', suffixText: 'yrs'),
                onChanged: (_) => _emit(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Years with diabetes'),
                onChanged: (_) => _emit(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Older age and long-standing diabetes make low alerts lead a little more.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weight,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Weight', suffixText: 'kg'),
                onChanged: (_) => _emit(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _height,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Height', suffixText: 'cm'),
                onChanged: (_) => _emit(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
