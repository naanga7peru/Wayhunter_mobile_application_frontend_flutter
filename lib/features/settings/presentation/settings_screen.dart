import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/l10n/wayhunter_strings.dart';
import 'package:wayhunter_mobile/core/services/device_interfaces.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_gate.dart';
import 'package:wayhunter_mobile/features/notifications/data/notifications_api.dart';
import 'package:wayhunter_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/trip_plan_widgets.dart';

const settingsRoute = 'settings.home';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.permissions,
    required this.notifications,
  });

  final DevicePermissions permissions;
  final NotificationsApi notifications;

  void _open(BuildContext context, Widget body) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WayhunterPageScaffold(appBar: AppBar(), body: body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => TripContent(
    title: 'Settings',
    children: [
      WayhunterSurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (label, icon, screen) in <(String, IconData, Widget)>[
              (
                'Account & Security',
                Icons.lock_outline,
                const _AccountSecurity(),
              ),
              ('Language', Icons.language, const _LanguageSettings()),
              (
                'Privacy & Permissions',
                Icons.privacy_tip_outlined,
                _PrivacySettings(permissions: permissions),
              ),
              (
                'Notification preferences',
                Icons.notifications_outlined,
                NotificationPreferencesScreen(api: notifications),
              ),
              ('Help & About', Icons.info_outline, const _HelpAbout()),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(context, screen),
              ),
            const Divider(height: 1),
            const AuthSignOutTile(),
          ],
        ),
      ),
    ],
  );
}

class _AccountSecurity extends StatelessWidget {
  const _AccountSecurity();

  @override
  Widget build(BuildContext context) => const TripContent(
    title: 'Account & Security',
    children: [
      WayhunterSurfaceCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Password recovery'),
          subtitle: Text(
            'To reset a forgotten password, sign out and choose Forgot Password on Sign In.',
          ),
        ),
      ),
      WayhunterUnavailableView(
        title: 'Change password unavailable',
        message:
            'Changing the password from a signed-in session is unavailable.',
      ),
      WayhunterUnavailableView(
        title: 'Account deletion unavailable',
        message: 'Account deletion cannot be requested from this app.',
      ),
    ],
  );
}

class _LanguageSettings extends StatefulWidget {
  const _LanguageSettings();

  @override
  State<_LanguageSettings> createState() => _LanguageSettingsState();
}

class _LanguageSettingsState extends State<_LanguageSettings> {
  Locale _preview = const Locale('en');

  static const _names = {'en': 'English', 'ta': 'Tamil', 'si': 'Sinhala'};

  @override
  Widget build(BuildContext context) {
    final strings = WayhunterStrings.forLocale(_preview);
    return TripContent(
      title: 'Language settings',
      children: [
        const Text('App interface: English'),
        const Text(
          'Preview shared labels below. This choice only applies while this screen is open.',
        ),
        WayhunterSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              const Text('Preview language'),
              DropdownButton<Locale>(
                value: _preview,
                isExpanded: true,
                items: [
                  for (final locale in WayhunterStrings.supportedLocales)
                    DropdownMenuItem(
                      value: locale,
                      child: Text(_names[locale.languageCode]!),
                    ),
                ],
                onChanged: (locale) {
                  if (locale != null) setState(() => _preview = locale);
                },
              ),
              Text(strings.loading),
              Text(strings.retry),
              Text(strings.confirm),
              Text(strings.cancel),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacySettings extends StatefulWidget {
  const _PrivacySettings({required this.permissions});
  final DevicePermissions permissions;

  @override
  State<_PrivacySettings> createState() => _PrivacySettingsState();
}

class _PrivacySettingsState extends State<_PrivacySettings> {
  List<DevicePermissionStatus>? _statuses;
  bool _checking = false;
  bool _failed = false;

  Future<void> _check() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _failed = false;
      _statuses = null;
    });
    try {
      final statuses = await Future.wait(
        DevicePermission.values.map(widget.permissions.check),
      );
      if (mounted) setState(() => _statuses = statuses);
    } on DeviceUnavailableException {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _permissionLabel(DevicePermission permission) => switch (permission) {
    DevicePermission.location => 'Location',
    DevicePermission.camera => 'Camera',
    DevicePermission.microphone => 'Microphone',
  };

  String _statusLabel(DevicePermissionStatus status) => switch (status) {
    DevicePermissionStatus.granted => 'Allowed on this device',
    DevicePermissionStatus.denied => 'Denied on this device',
    DevicePermissionStatus.permanentlyDenied => 'Blocked on this device',
    DevicePermissionStatus.unavailable => 'Device status unavailable',
  };

  @override
  Widget build(BuildContext context) => TripContent(
    title: 'Privacy & Permissions',
    children: [
      const WayhunterHeader(title: 'Device permissions'),
      const Text(
        'Check the permissions reported by this device. To change a permission, use your device settings.',
      ),
      if (_checking)
        const WayhunterLoadingView(label: 'Checking device permissions'),
      if (_failed)
        WayhunterErrorView(
          title: 'Could not check device permissions',
          onRetry: _check,
        )
      else
        WayhunterButton.secondary(
          label: 'Check device permissions',
          onPressed: _checking ? null : _check,
        ),
      if (_statuses case final statuses?)
        WayhunterSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, permission) in DevicePermission.values.indexed)
                ListTile(
                  title: Text(_permissionLabel(permission)),
                  subtitle: Text(_statusLabel(statuses[index])),
                ),
            ],
          ),
        ),
      const WayhunterUnavailableView(
        title: 'Trip GPS consent unavailable here',
        message:
            'Trip GPS sharing requires separate consent for a specific session. Accepting a trip invitation does not enable sharing.',
      ),
      const WayhunterUnavailableView(
        title: 'Account privacy and contact discovery unavailable',
        message:
            'Profile visibility and contact access cannot be changed here.',
      ),
    ],
  );
}

class _HelpAbout extends StatelessWidget {
  const _HelpAbout();

  @override
  Widget build(BuildContext context) => const TripContent(
    title: 'Help & About',
    children: [
      WayhunterSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            WayhunterHeader(title: 'Wayhunter'),
            Text(
              'Plan trips in Traveller, review invitations in Friends, and manage notification preferences from Settings.',
            ),
            Text('For a forgotten password, use Forgot Password on Sign In.'),
          ],
        ),
      ),
      WayhunterUnavailableView(title: 'In-app support unavailable'),
    ],
  );
}
