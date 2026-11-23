import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/leaderboards/data/leaderboard_preview.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';
import 'package:wayhunter_mobile/shared/presentation/person2_content.dart';

extension on ModuleId {
  String get category => switch (this) {
    ModuleId.traveler => 'Traveller',
    ModuleId.hunter => 'Hunter',
    ModuleId.game => 'Game',
  };

  // Draft BRD metrics used only to label synthetic preview values.
  String get previewMetric => switch (this) {
    ModuleId.traveler => 'valid finished trips',
    ModuleId.hunter => 'approved Hunter Coins',
    ModuleId.game => 'approved Game Coins',
  };
}

class LeaderboardHomeScreen extends StatefulWidget {
  const LeaderboardHomeScreen({
    super.key,
    required this.initialModule,
    this.previewLoader = loadLeaderboardPreview,
  });

  final ModuleId initialModule;
  final LeaderboardPreviewLoader previewLoader;

  @override
  State<LeaderboardHomeScreen> createState() => _LeaderboardHomeScreenState();
}

class _LeaderboardHomeScreenState extends State<LeaderboardHomeScreen> {
  late ModuleId _module = widget.initialModule;
  Future<List<LeaderboardEntry>?>? _preview;

  void _loadPreview() {
    _preview = Future.sync(() => widget.previewLoader(_module))
        .then<List<LeaderboardEntry>?>(
          (entries) => entries,
          onError: (Object _) => null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Person2Content(
      children: [
        const WayhunterHeader(title: 'Leaderboard'),

        Wrap(
          spacing: WayhunterLayout.small,
          runSpacing: WayhunterLayout.small,
          children: [
            for (final module in ModuleId.values)
              ChoiceChip(
                label: Text(module.category),
                selected: module == _module,
                selectedColor: WayhunterColors.moduleAccent(module),
                onSelected: (selected) {
                  if (!selected) return;
                  setState(() {
                    _module = module;
                    if (_preview != null) _loadPreview();
                  });
                },
              ),
          ],
        ),

        WayhunterHeader(title: '${_module.category} rankings'),
        if (kDebugMode)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() {
                if (_preview == null) {
                  _loadPreview();
                } else {
                  _preview = null;
                }
              }),
              child: Text(
                preview == null ? 'Open DEMO preview' : 'Exit DEMO preview',
              ),
            ),
          ),

        if (preview == null)
          const WayhunterUnavailableView(
            title: 'Rankings unavailable',
            message: 'Official rankings are currently unavailable.',
          )
        else ...[
          const _DemoLabel(),

          FutureBuilder<List<LeaderboardEntry>?>(
            future: preview,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(WayhunterLayout.large),
                  child: WayhunterLoadingView(label: 'Loading DEMO rankings'),
                );
              }
              final entries = snapshot.data;
              if (entries == null) {
                return WayhunterErrorView(
                  title: 'Could not load DEMO rankings',
                  onRetry: () => setState(_loadPreview),
                );
              }
              if (entries.isEmpty) {
                return const WayhunterEmptyView(title: 'No DEMO rankings yet');
              }
              return Column(
                children: [
                  for (final entry in entries)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: WayhunterLayout.small,
                      ),
                      child: WayhunterSurfaceCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          selected: entry.user.id == previewCurrentUser.id,
                          selectedColor: WayhunterColors.moduleInk(_module),
                          title: Text(entry.displayName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                label: 'Position ${entry.position}',
                                excludeSemantics: true,
                                child: Text('#${entry.position}'),
                              ),
                              if (entry.user.id == previewCurrentUser.id)
                                const Text('You (DEMO)'),
                              if (entry.score case final score?)
                                Text('$score ${_module.previewMetric}'),
                            ],
                          ),
                          trailing: isNavigationId(entry.user.id)
                              ? const Icon(Icons.chevron_right)
                              : null,
                          onTap: isNavigationId(entry.user.id)
                              ? () => _openRanking(context, entry.user, entries)
                              : null,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  void _openRanking(
    BuildContext context,
    UserRef user,
    List<LeaderboardEntry> entries,
  ) {
    final module = _module;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            _UserRankingScreen(module: module, user: user, entries: entries),
      ),
    );
  }
}

class _UserRankingScreen extends StatelessWidget {
  const _UserRankingScreen({
    required this.module,
    required this.user,
    required this.entries,
  });

  final ModuleId module;
  final UserRef user;
  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final entry = entries
        .where((entry) => entry.user.id == user.id)
        .firstOrNull;

    return WayhunterPageScaffold(
      appBar: AppBar(),
      body: Person2Content(
        children: [
          const WayhunterHeader(title: 'Ranking detail'),
          const _DemoLabel(),

          if (entry == null)
            const WayhunterUnavailableView(title: 'Ranking detail unavailable')
          else
            WayhunterSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WayhunterHeader(
                    title: entry.displayName,
                    subtitle: '${module.category} ranking',
                  ),

                  Text('Position #${entry.position}'),
                  if (entry.score case final score?)
                    Text('$score ${module.previewMetric}'),
                  if (user.id == previewCurrentUser.id)
                    const Text('You (DEMO)'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DemoLabel extends StatelessWidget {
  const _DemoLabel();

  @override
  Widget build(BuildContext context) => const WayhunterStatusIndicator(
    label: 'DEMO · Sample rankings',
    tone: WayhunterStatusTone.warning,
  );
}
