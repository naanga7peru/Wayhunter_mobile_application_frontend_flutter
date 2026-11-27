import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/wayhunter_module.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/advertisements/data/home_advertisements_api.dart';
import 'package:wayhunter_mobile/features/advertisements/presentation/home_banner.dart';
import 'package:wayhunter_mobile/features/profile/data/my_profile_api.dart';
import 'package:wayhunter_mobile/features/profile/presentation/account_read_panel.dart';
import 'package:wayhunter_mobile/features/notifications/presentation/notifications_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onSelectModule,
    this.profileApi,
    this.advertisementsApi,
  });

  final MyProfileApi? profileApi;
  final HomeAdvertisementsApi? advertisementsApi;
  final ValueChanged<ModuleId> onSelectModule;

  static const scenicAsset =
      'assets/images/backgrounds/wayhunter_auth_home_bg.png';

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: Color(0xFF0A1420)),
      Image.asset(
        scenicAsset,
        alignment: Alignment.topCenter,
        fit: BoxFit.cover,
        semanticLabel: 'WAYHUNTER',
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xC9082029)],
            stops: [0.25, 1],
          ),
        ),
      ),
      SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              WayhunterLayout.pagePadding,
              (constraints.maxHeight - 320).clamp(
                64.0,
                (constraints.maxHeight * .35).clamp(96.0, 300.0),
              ),
              WayhunterLayout.pagePadding,
              WayhunterLayout.pagePadding + WayhunterLayout.medium,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: WayhunterLayout.contentWidth,
                ),
                child: WayhunterSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (profileApi case final MyProfileApi profile)
                        AccountReadPanel<MyProfile?>(
                          label: 'profile',
                          load: profile.read,
                          content: (owner) => owner == null
                              ? const Text('Profile details unavailable')
                              : _HomeProfileHeader(profile: owner),
                        ),
                      const WayhunterHeader(title: 'Choose a module'),
                      for (final module in ModuleId.values) ...[
                        const SizedBox(height: WayhunterLayout.medium),
                        _ModuleTile(
                          module: module,
                          onTap: () => onSelectModule(module),
                        ),
                      ],
                      if (profileApi != null) ...[
                        const SizedBox(height: WayhunterLayout.medium),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.person_outline),
                              label: const Text('My profile'),
                              onPressed: () => const AppDestination(
                                AppRoutes.profile,
                              ).open(context),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.notifications_outlined),
                              label: const Text('Notifications'),
                              onPressed: () => const AppDestination(
                                notificationsRoute,
                              ).open(context),
                            ),
                          ],
                        ),
                      ],
                      if (advertisementsApi
                          case final HomeAdvertisementsApi ads)
                        AccountReadPanel<List<HomeAdvertisement>>(
                          label: 'advertisements',
                          load: ads.read,
                          content: (eligible) => HomeBanner(
                            advertisements: eligible,
                            loadAdvertisements: ads.read,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _HomeProfileHeader extends StatelessWidget {
  const _HomeProfileHeader({required this.profile});

  final MyProfile profile;

  @override
  Widget build(BuildContext context) {
    const fallback = CircleAvatar(
      backgroundColor: WayhunterColors.surface,
      foregroundColor: WayhunterColors.ink,
      child: Icon(Icons.person_outline),
    );
    final url = safePublicHttpsUrl(profile.avatarUrl?.toString());
    return Row(
      children: [
        SizedBox.square(
          dimension: WayhunterLayout.minimumTap,
          child: ClipOval(
            child: url == null
                ? fallback
                : Image.network(
                    url.toString(),
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    frameBuilder: (_, child, frame, _) =>
                        frame == null ? fallback : child,
                    errorBuilder: (_, _, _) => fallback,
                  ),
          ),
        ),
        const SizedBox(width: WayhunterLayout.medium),
        Expanded(
          child: WayhunterHeader(title: 'Hello, ${profile.displayName}'),
        ),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module, required this.onTap});
  final ModuleId module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = WayhunterColors.moduleInk(module);
    return WayhunterSurfaceCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        minTileHeight: 56,
        leading: CircleAvatar(
          backgroundColor: WayhunterColors.moduleAccent(
            module,
          ).withValues(alpha: .24),
          foregroundColor: ink,
          child: Icon(switch (module) {
            ModuleId.traveler => Icons.explore_outlined,
            ModuleId.hunter => Icons.place_outlined,
            ModuleId.game => Icons.sports_esports_outlined,
          }),
        ),
        title: Text(
          module.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: Icon(Icons.chevron_right, color: ink),
        onTap: onTap,
      ),
    );
  }
}
