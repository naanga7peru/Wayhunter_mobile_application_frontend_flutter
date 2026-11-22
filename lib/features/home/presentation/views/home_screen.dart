import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/wayhunter_module.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onSelectModule});
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
                  (constraints.maxHeight * .35).clamp(96.0, 300.0),
                  WayhunterLayout.pagePadding,
                  WayhunterLayout.pagePadding,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: WayhunterLayout.contentWidth),
                    child: WayhunterSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const WayhunterHeader(title: 'Choose a module'),
                          for (final module in ModuleId.values) ...[
                            const SizedBox(height: WayhunterLayout.medium),
                            _ModuleTile(
                              module: module,
                              onTap: () => onSelectModule(module),
                            ),
                          ],
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
          backgroundColor:
              WayhunterColors.moduleAccent(module).withValues(alpha: .24),
          foregroundColor: ink,
          child: Icon(switch (module) {
            ModuleId.traveler => Icons.explore_outlined,
            ModuleId.hunter => Icons.place_outlined,
            ModuleId.game => Icons.sports_esports_outlined,
          }),
        ),
        title:
            Text(module.title, style: Theme.of(context).textTheme.titleMedium),
        trailing: Icon(Icons.chevron_right, color: ink),
        onTap: onTap,
      ),
    );
  }
}
