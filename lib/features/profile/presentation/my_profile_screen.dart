import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_gate.dart';
import 'package:wayhunter_mobile/features/friends/presentation/friends_screen.dart';
import 'package:wayhunter_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:wayhunter_mobile/features/profile/data/my_profile_api.dart';
import 'package:wayhunter_mobile/features/profile/presentation/account_read_panel.dart';
import 'package:wayhunter_mobile/features/settings/presentation/settings_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key, this.api});

  /// Only the standalone shell navigation harness has no authenticated API.
  final MyProfileApi? api;

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  int _revision = 0;

  Future<void> _edit(MyProfileApi api) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WayhunterPageScaffold(
          appBar: AppBar(title: const Text('Edit Profile')),
          body: ListView(
            padding: const EdgeInsets.all(WayhunterLayout.pagePadding),
            children: [
              AccountReadPanel<MyProfile?>(
                label: 'profile',
                load: api.read,
                content: (profile) => profile == null
                    ? const WayhunterEmptyView(
                        title: 'No profile details available',
                      )
                    : _ProfileForm(api: api, profile: profile),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted && saved == true) setState(() => _revision++);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(WayhunterLayout.pagePadding),
      children: [
        const WayhunterHeader(title: 'Profile'),
        if (widget.api case final MyProfileApi source)
          AccountReadPanel<MyProfile?>(
            key: ValueKey(_revision),
            label: 'profile',
            load: source.read,
            content: (profile) => profile == null
                ? const WayhunterEmptyView(
                    title: 'No profile details available',
                  )
                : _ProfileDetails(profile: profile),
          )
        else
          const Text('Development preview'),
        for (final (label, route) in [
          ('Wallet', AppRoutes.wallet),
          ('My Hunts', AppRoutes.myHunts),
          ('My Games', AppRoutes.myGames),
        ])
          ListTile(
            title: Text(label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => AppDestination(route).open(context),
          ),
        const AuthSignOutTile(),
        if (widget.api case final api?) ...[
          ListTile(
            title: const Text('Friends'),
            onTap: () => const AppDestination(friendsRoute).open(context),
          ),
          ListTile(title: const Text('Edit Profile'), onTap: () => _edit(api)),
          ListTile(
            title: const Text('Settings'),
            onTap: () => const AppDestination(settingsRoute).open(context),
          ),
          ListTile(
            title: const Text('Notifications'),
            onTap: () => const AppDestination(notificationsRoute).open(context),
          ),
        ],
      ],
    ),
  );
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({required this.api, required this.profile});
  final MyProfileApi api;
  final MyProfile profile;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.displayName);
  late final _bio = TextEditingController(text: widget.profile.bio);
  bool _saving = false;
  bool _reloadRequired = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _reloadRequired || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.update(
        displayName: _name.text,
        bio: _bio.text.trim().isEmpty ? null : _bio.text,
      );
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _reloadRequired = switch (error.kind) {
          ApiError.rejected || ApiError.unavailable => false,
          _ => true,
        };
        _error = switch (error.kind) {
          ApiError.unauthorized ||
          ApiError.forbidden => 'Your account cannot update this profile.',
          ApiError.rejected => 'The service rejected these profile details.',
          ApiError.unavailable => 'Profile editing is unavailable right now.',
          _ => 'The save could not be confirmed. Reopen Edit Profile to check.',
        };
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: WayhunterLayout.medium,
      children: [
        TextFormField(
          controller: _name,
          enabled: !_saving,
          decoration: const InputDecoration(labelText: 'Display name'),
          validator: (value) {
            final length = value?.trim().length ?? 0;
            return length == 0 || length > 200
                ? 'Enter a display name from 1 to 200 characters.'
                : null;
          },
        ),
        TextFormField(
          controller: _bio,
          enabled: !_saving,
          decoration: const InputDecoration(labelText: 'Bio'),
          minLines: 2,
          maxLines: 5,
          validator: (value) => (value?.length ?? 0) > 500
              ? 'Enter a bio up to 500 characters.'
              : null,
        ),
        if (_error case final message?)
          Semantics(liveRegion: true, child: Text(message)),
        FilledButton(
          onPressed: _saving || _reloadRequired ? null : _save,
          child: Text(_saving ? 'Saving profile…' : 'Save profile'),
        ),
      ],
    ),
  );
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.profile});
  final MyProfile profile;

  @override
  Widget build(BuildContext context) => WayhunterSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        if (profile.avatarUrl case final Uri url)
          ClipOval(
            child: Image.network(
              url.toString(),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              semanticLabel: 'Profile avatar',
              errorBuilder: (_, _, _) =>
                  const CircleAvatar(child: Icon(Icons.person_outline)),
            ),
          ),
        Text(
          profile.displayName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(profile.email),
        if (profile.bio case final String bio when bio.trim().isNotEmpty)
          Text(bio),
        if (profile.phoneNumber case final String phone
            when phone.trim().isNotEmpty)
          Text(phone),
      ],
    ),
  );
}
