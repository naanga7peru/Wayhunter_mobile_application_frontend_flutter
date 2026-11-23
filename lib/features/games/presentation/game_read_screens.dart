import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';

import '../domain/games_reader.dart';
import 'game_navigation.dart';

class GameDiscovery extends StatelessWidget {
  const GameDiscovery({super.key, required this.reader});

  final GamesReader reader;

  @override
  Widget build(BuildContext context) => _GameRead(
    read: () async {
      final games = await reader.readGames();
      final now = DateTime.now();
      return games.where((game) => game.expiresAt.isAfter(now)).toList();
    },
    builder: (context, games) => games.isEmpty
        ? const WayhunterEmptyView(
            title: 'No available games',
            message: 'Check back for newly published games.',
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: WayhunterLayout.medium,
            children: [
              for (final game in games)
                WayhunterSurfaceCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(game.title),
                    subtitle: Text('${game.durationMinutes} minutes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed<void>(gameDetailsRoute, arguments: game.id),
                  ),
                ),
            ],
          ),
  );
}

class GameDetailsScreen extends StatelessWidget {
  const GameDetailsScreen({super.key, required this.reader, required this.id});

  final GamesReader? reader;
  final String id;

  @override
  Widget build(BuildContext context) => GameContent(
    children: [
      const WayhunterHeader(title: 'Game Details'),
      if (reader case final source?)
        _GameRead(
          read: () => source.readGame(id),
          builder: (context, details) {
            if (details == null) {
              return const WayhunterUnavailableView(title: 'Game not found');
            }
            final game = details.game;
            if (!game.expiresAt.isAfter(DateTime.now())) {
              return const WayhunterUnavailableView(title: 'Game has expired');
            }
            return WayhunterSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: WayhunterLayout.small,
                children: [
                  WayhunterHeader(title: game.title),
                  if (game.description case final description?)
                    Text(description),
                  Text('${game.durationMinutes} minutes'),
                  Text('Stages: ${details.stageCount}'),
                  Text('Published: ${_utc(game.publishedAt)}'),
                  Text('Expires: ${_utc(game.expiresAt)}'),
                  Text(_remaining(game.expiresAt)),
                  const Text('Creators cannot play or win their own games.'),
                  const Text(
                    'Each game can have one eligible Admin-verified winner.',
                  ),
                  const Text(
                    'Games expire 30 days after Admin creation approval and remain in the creator’s archive.',
                  ),
                  const WayhunterButton.primary(
                    label: 'Accept Game',
                    onPressed: null,
                  ),
                ],
              ),
            );
          },
        )
      else
        const WayhunterUnavailableView(title: 'Game details unavailable'),
    ],
  );
}

class MyGameAttemptsScreen extends StatelessWidget {
  const MyGameAttemptsScreen({super.key, required this.reader});

  final GamesReader? reader;

  @override
  Widget build(BuildContext context) => GameContent(
    children: [
      const WayhunterHeader(
        title: 'My Game Attempts',
        subtitle: 'Player history',
      ),
      if (reader case final source?)
        _GameRead(
          read: source.readMyAttempts,
          builder: (context, attempts) => attempts.isEmpty
              ? const WayhunterEmptyView(title: 'No game attempts yet')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: WayhunterLayout.medium,
                  children: [
                    for (final attempt in attempts)
                      WayhunterSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WayhunterHeader(title: attempt.status.label),
                            Text('Attempt ID: ${attempt.id}'),
                            Text('Game ID: ${attempt.gameId}'),
                            Text('Started: ${_utc(attempt.startedAt)}'),
                            if (attempt.deadline case final deadline?)
                              Text('Deadline: ${_utc(deadline)}'),
                            Text(
                              'Current step: ${attempt.currentStepNumber} of ${attempt.totalSteps}',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        )
      else
        const WayhunterUnavailableView(title: 'Player history unavailable'),
    ],
  );
}

String _utc(DateTime date) => '${date.toString().split('.').first} UTC';

String _remaining(DateTime expiry) {
  final remaining = expiry.difference(DateTime.now());
  if (remaining <= Duration.zero) return 'Scheduled expiry has passed';
  if (remaining.inDays > 0) {
    return '${remaining.inDays}d ${remaining.inHours.remainder(24)}h remaining';
  }
  if (remaining.inHours > 0) return '${remaining.inHours}h remaining';
  if (remaining.inMinutes > 0) return '${remaining.inMinutes} min remaining';
  return 'Less than a minute remaining';
}

class _GameRead<T> extends StatefulWidget {
  const _GameRead({required this.read, required this.builder});

  final Future<T> Function() read;
  final Widget Function(BuildContext, T) builder;

  @override
  State<_GameRead<T>> createState() => _GameReadState<T>();
}

class _GameReadState<T> extends State<_GameRead<T>> {
  late Future<AsyncSnapshot<T>> _result = _read();

  Future<AsyncSnapshot<T>> _read() async {
    try {
      return AsyncSnapshot.withData(ConnectionState.done, await widget.read());
    } catch (error, stack) {
      return AsyncSnapshot.withError(ConnectionState.done, error, stack);
    }
  }

  void _retry() {
    final result = _read();
    setState(() {
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AsyncSnapshot<T>>(
    key: ObjectKey(_result),
    future: _result,
    builder: (context, response) {
      final snapshot = response.data;
      if (snapshot == null) {
        return const WayhunterLoadingView(label: 'Loading Games data');
      }
      if (snapshot.hasError) {
        final error = snapshot.error;
        if (error is ApiException) {
          if (error.kind == ApiError.unavailable || error.statusCode == 503) {
            return WayhunterUnavailableView(
              title: 'Games service unavailable',
              action: WayhunterButton.secondary(
                label: 'Retry',
                onPressed: _retry,
              ),
            );
          }
          if (error.kind == ApiError.unauthorized) {
            return WayhunterErrorView(
              title: 'An active account is required',
              onRetry: _retry,
            );
          }
        }
        return WayhunterErrorView(
          title: 'Could not load Games data',
          onRetry: _retry,
        );
      }
      return widget.builder(context, snapshot.data as T);
    },
  );
}
