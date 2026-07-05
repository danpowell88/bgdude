import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/user_profile.dart';
import '../state/providers.dart';
import 'profile_form.dart';

/// Edit the user profile from Settings. Fields are all optional and feed the models only
/// where usable.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late UserProfile _draft = ref.read(userProfileProvider);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Your details stay on the device (encrypted) and are used only where they '
            'help the models — nothing is uploaded.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ProfileForm(
            initial: _draft,
            onChanged: (p) => _draft = p,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await ref.read(userProfileProvider.notifier).save(_draft);
              messenger.showSnackBar(
                  const SnackBar(content: Text('Profile saved.')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
