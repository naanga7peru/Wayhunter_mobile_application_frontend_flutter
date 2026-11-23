import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_navigation.dart';

import '../domain/games_reader.dart';
import 'game_read_screens.dart';

class PlayGameScreen extends StatelessWidget {
  const PlayGameScreen({super.key, this.enableDemo = false, this.reader});

  final bool enableDemo;
  final GamesReader? reader;

  @override
  Widget build(BuildContext context) => GameContent(
    children: [
      const WayhunterHeader(
        title: 'Play Game',
        subtitle: 'Browse published games and check their details.',
      ),
      if (reader case final source?)
        GameDiscovery(reader: source)
      else
        const WayhunterUnavailableView(
          title: 'Live discovery unavailable',
          message: 'Available games require a connected game service.',
        ),
      if (enableDemo)
        WayhunterButton.secondary(
          label: 'Browse DEMO games',
          onPressed: () => _openPage(context, const _DemoGamesScreen()),
        ),
    ],
  );
}

class _DemoGame {
  const _DemoGame(this.title, this.district, this.description, this.hint);

  final String title;
  final String district;
  final String description;
  final String hint;
}

const _demoGames = [
  _DemoGame(
    'Coastal Clues',
    'Galle',
    'Follow clues about landmarks along the coast.',
    'Look for a white tower overlooking the water.',
  ),
  _DemoGame(
    'Garden Trail',
    'Kandy',
    'Follow clues about landmarks in a public garden.',
    'Look for an arch with climbing plants.',
  ),
];

class _DemoGamesScreen extends StatelessWidget {
  const _DemoGamesScreen();

  @override
  Widget build(BuildContext context) => _DemoPage(
    title: 'Available Games',
    children: [
      for (final game in _demoGames)
        WayhunterSurfaceCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            title: Text(game.title),
            subtitle: Text('DEMO · ${game.district}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openPage(context, _GameDetailsScreen(game: game)),
          ),
        ),
    ],
  );
}

class _GameDetailsScreen extends StatelessWidget {
  const _GameDetailsScreen({required this.game});

  final _DemoGame game;

  @override
  Widget build(BuildContext context) => _DemoPage(
    title: 'Game Details',
    children: [
      WayhunterHeader(title: game.title, subtitle: game.district),
      Text(game.description),
      WayhunterButton.primary(
        label: 'Accept Game',
        onPressed: () => _openPage(context, _AcceptGameScreen(game: game)),
      ),
      const WayhunterSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: WayhunterLayout.small,
          children: [
            WayhunterHeader(title: 'Rules'),
            Text('Creators cannot play or win their own games.'),
            Text('Each game can have one eligible Admin-verified winner.'),
            Text(
              'Admin reviews game creation and final player results separately.',
            ),
            Text('Stage proof must come from the live camera.'),
            Text('Three rejected proofs close the attempt.'),
            Text(
              'Games expire 720 hours after server-recorded Admin creation approval. '
              'Expired games close to play and remain in the creator’s archive.',
            ),
          ],
        ),
      ),
    ],
  );
}

class _AcceptGameScreen extends StatelessWidget {
  const _AcceptGameScreen({required this.game});

  final _DemoGame game;

  @override
  Widget build(BuildContext context) => _DemoPage(
    title: 'Accept Game',
    children: [
      const WayhunterUnavailableView(
        title: 'Game acceptance unavailable',
        message:
            'A connected game service must check eligibility and create an attempt.',
      ),
      WayhunterButton.primary(label: 'Start attempt', onPressed: null),
      WayhunterButton.secondary(
        label: 'Preview DEMO stage',
        onPressed: () => _openPage(context, _StageChallengeScreen(game: game)),
      ),
    ],
  );
}

class _StageChallengeScreen extends StatelessWidget {
  const _StageChallengeScreen({required this.game});

  final _DemoGame game;

  @override
  Widget build(BuildContext context) => _DemoPage(
    title: 'Stage Challenge',
    children: [
      WayhunterHeader(title: game.title, subtitle: 'Stage 1 of 1'),
      WayhunterSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: WayhunterLayout.small,
          children: [
            const WayhunterHeader(title: 'Hint'),
            Text(game.hint),
          ],
        ),
      ),
      WayhunterButton.primary(
        label: 'Preview Live Camera Proof',
        onPressed: () => _openPage(context, const _LiveCameraProofScreen()),
      ),
      WayhunterButton.secondary(
        label: 'Browse DEMO results',
        onPressed: () => _openPage(context, const _DemoResultsScreen()),
      ),
    ],
  );
}

class _LiveCameraProofScreen extends StatelessWidget {
  const _LiveCameraProofScreen();

  @override
  Widget build(BuildContext context) => _DemoPage(
    title: 'Live Camera Proof',
    children: [
      const WayhunterUnavailableView(
        title: 'Live camera unavailable',
        message:
            'Proof requires a connected live capture adapter and evidence upload service.',
      ),
      WayhunterButton.primary(label: 'Capture proof', onPressed: null),
    ],
  );
}

enum _DemoResult {
  pending(
    'Pending Admin Verification',
    'This example shows a completion awaiting the separate Admin winner review.',
  ),
  rejected(
    'Rejected',
    'Example reason: Proof did not show the requested landmark. '
        'The review service determines whether another submission is allowed.',
  ),
  expired(
    'Expired',
    'The 720-hour window from server-recorded Admin approval has ended. '
        'Players can no longer start, resume, or complete this game.',
  ),
  gameOver('Game Over', 'Three rejected proofs closed this example attempt.');

  const _DemoResult(this.title, this.description);

  final String title;
  final String description;
}

class _DemoResultsScreen extends StatelessWidget {
  const _DemoResultsScreen();

  @override
  Widget build(BuildContext context) => _DemoPage(
    title: 'Result previews',
    children: [
      for (final result in _DemoResult.values)
        WayhunterButton.secondary(
          label: result.title,
          onPressed: () => _openPage(
            context,
            _DemoPage(
              title: result.title,
              children: [WayhunterSurfaceCard(child: Text(result.description))],
            ),
          ),
        ),
    ],
  );
}

class _DemoPage extends StatelessWidget {
  const _DemoPage({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final titleInBody =
        MediaQuery.sizeOf(context).width <
        MediaQuery.textScalerOf(context).scale(360);
    return WayhunterPageScaffold(
      appBar: AppBar(title: titleInBody ? null : Text(title)),
      body: GameContent(
        children: [
          if (titleInBody) WayhunterHeader(title: title),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: WayhunterStatusIndicator(
              label: 'DEMO · Preview only',
              tone: WayhunterStatusTone.warning,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

void _openPage(BuildContext context, Widget page) {
  Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
}
