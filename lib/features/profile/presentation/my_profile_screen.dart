import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_gate.dart';
import 'package:wayhunter_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:wayhunter_mobile/features/profile/data/my_profile_api.dart';
import 'package:wayhunter_mobile/features/profile/presentation/account_read_panel.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key, this.api});

  /// Only the standalone shell navigation harness has no authenticated API.
  final MyProfileApi? api;

  void _unavailable(BuildContext context, String label) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: const Text('This feature is currently unavailable.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(WayhunterLayout.pagePadding),
      children: [
        const WayhunterHeader(title: 'Profile'),
        if (api case final MyProfileApi source)
          AccountReadPanel<MyProfile?>(
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
        if (api != null) ...[
          for (final label in ['Edit Profile', 'Friends', 'Settings'])
            ListTile(
              title: Text(label),
              onTap: () => _unavailable(context, label),
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
