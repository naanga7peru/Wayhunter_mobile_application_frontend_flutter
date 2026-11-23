import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

const createGameRoute = 'games.create';
const playGameRoute = 'games.play';

class GameZoneScreen extends StatelessWidget {
  const GameZoneScreen({super.key});

  @override
  Widget build(BuildContext context) => GameContent(
    children: [
      WayhunterSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: WayhunterLayout.medium,
          children: [
            Icon(
              Icons.extension_outlined,
              color: WayhunterColors.moduleInk(ModuleId.game),
              size: 36,
            ),
            const WayhunterHeader(title: 'Game Zone'),
            WayhunterButton.primary(
              label: 'Create Game',
              onPressed: () =>
                  const AppDestination(createGameRoute).open(context),
            ),
            WayhunterButton.secondary(
              label: 'Play Game',
              onPressed: () =>
                  const AppDestination(playGameRoute).open(context),
            ),
            WayhunterButton.secondary(
              label: 'My Games',
              onPressed: () =>
                  const AppDestination(AppRoutes.myGames).open(context),
            ),
          ],
        ),
      ),
    ],
  );
}

class GameContent extends StatelessWidget {
  const GameContent({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(WayhunterLayout.pagePadding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: WayhunterLayout.contentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: WayhunterLayout.large,
            children: children,
          ),
        ),
      ),
    ),
  );
}
