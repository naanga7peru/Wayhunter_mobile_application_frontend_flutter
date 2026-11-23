import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_navigation.dart';

enum GameCreationStatus { pending, approved, rejected, archived }

class CreatedGameSummary {
  const CreatedGameSummary(this.title, this.status, {this.rejectionReason});

  final String title;
  final GameCreationStatus status;
  final String? rejectionReason;
}

class MyGamesScreen extends StatefulWidget {
  const MyGamesScreen({super.key, this.loadHistory, this.enableDemo = false});

  final Future<List<CreatedGameSummary>> Function()? loadHistory;
  final bool enableDemo;

  @override
  State<MyGamesScreen> createState() => _MyGamesScreenState();
}

class _MyGamesScreenState extends State<MyGamesScreen> {
  static const _examples = [
    CreatedGameSummary('Sample coastal clues', GameCreationStatus.pending),
    CreatedGameSummary('Sample forest clues', GameCreationStatus.approved),
    CreatedGameSummary(
      'Sample garden clues',
      GameCreationStatus.rejected,
      rejectionReason: 'Sample reason: A clue needs a clearer description.',
    ),
    CreatedGameSummary('Sample lakeside clues', GameCreationStatus.archived),
  ];

  Future<List<CreatedGameSummary>>? _history;
  bool _showDemo = false;

  @override
  void didUpdateWidget(MyGamesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadHistory != widget.loadHistory) _history = null;
    if (!widget.enableDemo) _showDemo = false;
  }

  @override
  Widget build(BuildContext context) => GameContent(
    children: [
      const WayhunterHeader(
        title: 'My Games',
        subtitle: 'Track review and archive status for games you created.',
      ),
      if (_showDemo) ...[
        const WayhunterStatusIndicator(
          label: 'Development demo data',
          tone: WayhunterStatusTone.info,
        ),
        WayhunterButton.secondary(
          label: 'Return to My Games',
          onPressed: () => setState(() => _showDemo = false),
        ),
        for (final game in _examples) _GameHistoryCard(game: game, demo: true),
      ] else if (widget.loadHistory case final load?)
        FutureBuilder<List<CreatedGameSummary>>(
          future: _history ??= Future.sync(load),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const WayhunterLoadingView(label: 'Loading games');
            }
            if (snapshot.hasError) {
              return WayhunterErrorView(
                title: 'Could not load games',
                onRetry: () => setState(() => _history = null),
              );
            }
            final games = snapshot.requireData;
            if (games.isEmpty) {
              return const WayhunterEmptyView(
                title: 'No games yet',
                message:
                    'Games you submit for creation review will appear here.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: WayhunterLayout.medium,
              children: [
                for (final game in games) _GameHistoryCard(game: game),
              ],
            );
          },
        )
      else
        WayhunterUnavailableView(
          title: 'Game history unavailable',
          message:
              'Your games will appear when the history service is connected.',
          action: widget.enableDemo
              ? WayhunterButton.secondary(
                  label: 'View development demo',
                  onPressed: () => setState(() => _showDemo = true),
                )
              : null,
        ),
    ],
  );
}

class _GameHistoryCard extends StatelessWidget {
  const _GameHistoryCard({required this.game, this.demo = false});

  final CreatedGameSummary game;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    final (label, tone, message) = switch (game.status) {
      GameCreationStatus.pending => (
        'Pending',
        WayhunterStatusTone.warning,
        'Awaiting Admin creation review.',
      ),
      GameCreationStatus.approved => (
        'Approved',
        WayhunterStatusTone.success,
        'Creation approved by Admin.',
      ),
      GameCreationStatus.rejected => (
        'Rejected',
        WayhunterStatusTone.danger,
        game.rejectionReason ?? 'Review reason unavailable.',
      ),
      GameCreationStatus.archived => (
        'Archived',
        WayhunterStatusTone.neutral,
        'Retained in your history after expiry.',
      ),
    };
    return WayhunterSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: WayhunterLayout.small,
        children: [
          Text(game.title, style: Theme.of(context).textTheme.titleMedium),
          WayhunterStatusIndicator(label: label, tone: tone),
          Text(message),
          if (demo) const Text('Development example'),
        ],
      ),
    );
  }
}
