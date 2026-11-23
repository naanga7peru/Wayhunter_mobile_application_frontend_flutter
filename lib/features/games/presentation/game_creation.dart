import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_navigation.dart';
import 'package:wayhunter_mobile/shared/presentation/person2_content.dart';

class _GameDraft {
  String title = '';
  String description = '';
  String district = '';
  String durationMinutes = '';
  final stages = [_StageDraft()];
}

class _StageDraft {
  String hint = '';
}

class CreateGameScreen extends StatefulWidget {
  const CreateGameScreen({super.key});

  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  final _form = GlobalKey<FormState>();
  final _draft = _GameDraft();

  void _openStages() {
    if (!validatePerson2Draft(_form.currentState!)) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => _StagesScreen(draft: _draft)),
    );
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: GameContent(
      children: [
        const WayhunterHeader(
          title: 'Create Game',
          subtitle: 'This draft is kept while the creation flow is open.',
        ),
        Person2DraftField(
          label: 'Game title',
          hint: 'Give players a short, memorable title',
          onChanged: (value) => _draft.title = value.trim(),
          validator: (value) => _required(value, 'Enter a game title.'),
        ),
        Person2DraftField(
          label: 'Description',
          hint: 'Describe the challenge players will explore',
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
          onChanged: (value) => _draft.description = value.trim(),
          validator: (value) => _required(value, 'Enter a description.'),
        ),
        Person2DraftField(
          label: 'District',
          hint: 'Enter the district where players will look',
          onChanged: (value) => _draft.district = value.trim(),
          validator: (value) => _required(value, 'Enter a district.'),
        ),
        Person2DraftField(
          label: 'Play duration (minutes)',
          hint: 'For example, 30',
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.number,
          onChanged: (value) => _draft.durationMinutes = value.trim(),
          validator: (value) {
            final input = (value ?? '').trim();
            if (!RegExp(r'^[0-9]+$').hasMatch(input) ||
                (int.tryParse(input) ?? 0) <= 0) {
              return 'Enter a positive whole number of minutes.';
            }
            return null;
          },
        ),
        const WayhunterUnavailableView(
          title: 'Cover image unavailable',
          message: 'Cover images require a connected media service.',
        ),
        WayhunterButton.primary(
          label: 'Stages and Hints',
          onPressed: _openStages,
        ),
      ],
    ),
  );
}

class _StagesScreen extends StatefulWidget {
  const _StagesScreen({required this.draft});

  final _GameDraft draft;

  @override
  State<_StagesScreen> createState() => _StagesScreenState();
}

class _StagesScreenState extends State<_StagesScreen> {
  final _form = GlobalKey<FormState>();
  List<_StageDraft> get _stages => widget.draft.stages;

  void _moveStage(int from, int to) {
    FocusScope.of(context).unfocus();
    setState(() => _stages.insert(to, _stages.removeAt(from)));
  }

  void _review() {
    if (!validatePerson2Draft(_form.currentState!)) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ReviewGameScreen(draft: widget.draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => WayhunterPageScaffold(
    appBar: AppBar(),
    body: Form(
      key: _form,
      child: GameContent(
        children: [
          const WayhunterHeader(
            title: 'Stages and Hints',
            subtitle:
                'Add a clue for each stage in the order players will see it.',
          ),
          for (var index = 0; index < _stages.length; index++)
            _StageEditor(
              key: ObjectKey(_stages[index]),
              stage: _stages[index],
              number: index + 1,
              onMoveUp: index > 0 ? () => _moveStage(index, index - 1) : null,
              onMoveDown: index < _stages.length - 1
                  ? () => _moveStage(index, index + 1)
                  : null,
              onRemove: _stages.length > 1
                  ? () => setState(() => _stages.removeAt(index))
                  : null,
            ),
          const WayhunterUnavailableView(
            title: 'Clue images unavailable',
            message: 'Creator gallery clues require a connected media service.',
          ),
          WayhunterButton.secondary(
            label: 'Add stage',
            onPressed: () => setState(() => _stages.add(_StageDraft())),
          ),
          WayhunterButton.primary(label: 'Review Game', onPressed: _review),
        ],
      ),
    ),
  );
}

class _StageEditor extends StatefulWidget {
  const _StageEditor({
    super.key,
    required this.stage,
    required this.number,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final _StageDraft stage;
  final int number;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  @override
  State<_StageEditor> createState() => _StageEditorState();
}

class _StageEditorState extends State<_StageEditor> {
  late final _hint = TextEditingController(text: widget.stage.hint);

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WayhunterSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Stage ${widget.number}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Wrap(
          children: [
            IconButton(
              tooltip: 'Move stage ${widget.number} up',
              onPressed: widget.onMoveUp,
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: 'Move stage ${widget.number} down',
              onPressed: widget.onMoveDown,
              icon: const Icon(Icons.arrow_downward),
            ),
            IconButton(
              tooltip: 'Remove stage ${widget.number}',
              onPressed: widget.onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        Person2DraftField(
          label: 'Stage ${widget.number} hint',
          hint: 'Give players a clue for this stage',
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          controller: _hint,
          keyboardType: TextInputType.multiline,
          onChanged: (value) => widget.stage.hint = value,
          validator: (value) =>
              _required(value, 'Enter a hint for this stage.'),
        ),
      ],
    ),
  );
}

class _ReviewGameScreen extends StatelessWidget {
  const _ReviewGameScreen({required this.draft});

  final _GameDraft draft;

  @override
  Widget build(BuildContext context) => WayhunterPageScaffold(
    appBar: AppBar(),
    body: GameContent(
      children: [
        const WayhunterHeader(
          title: 'Review Game',
          subtitle: 'Check the game details and clue order.',
        ),
        WayhunterSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: WayhunterLayout.small,
            children: [
              Text(draft.title, style: Theme.of(context).textTheme.titleLarge),
              Text(draft.description),
              Text('District: ${draft.district}'),
              Text('Play duration: ${draft.durationMinutes} minutes'),
              const Text('Cover image unavailable'),
            ],
          ),
        ),
        for (final (index, stage) in draft.stages.indexed)
          WayhunterSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: WayhunterLayout.small,
              children: [
                Text(
                  'Stage ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(stage.hint.trim()),
                const Text('Clue image unavailable'),
              ],
            ),
          ),
        WayhunterButton.secondary(
          label: 'Edit stages and hints',
          onPressed: () => Navigator.of(context).pop(),
        ),
        const WayhunterUnavailableView(
          title: 'Submission unavailable',
          message:
              'Submitting for Admin review requires the connected game and media services.',
        ),
        const WayhunterButton.primary(
          label: 'Submit for Admin review',
          onPressed: null,
        ),
      ],
    ),
  );
}

String? _required(String? value, String message) =>
    (value ?? '').trim().isEmpty ? message : null;
