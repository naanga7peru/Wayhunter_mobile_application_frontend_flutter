import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/memories/data/trip_memories_api.dart';
import 'package:wayhunter_mobile/features/memories/domain/trip_memory.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/trip_plan_widgets.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

const tripMemoriesRoute = 'traveller.activeTrip.memories';
const tripMemoryCreateRoute = 'traveller.activeTrip.memories.create';
const tripMemoryDetailsRoute = 'traveller.activeTrip.memories.details';

class TripMemoryDetailsArgs {
  const TripMemoryDetailsArgs({required this.plan, required this.memoryId});
  final TripPlanRef plan;
  final String memoryId;
}

String _memoryError(ApiException error) => switch (error.kind) {
  ApiError.unauthorized => 'Sign in again to access trip memories.',
  ApiError.forbidden => 'Your account cannot access this trip memory.',
  ApiError.notFound => 'This trip memory is no longer available.',
  ApiError.unavailable || ApiError.server =>
    'The private trip memory store is unavailable on this backend configuration.',
  ApiError.network || ApiError.timeout =>
    'Could not reach the trip memory service. Check your connection.',
  ApiError.conflict =>
    'This memory operation conflicts with a previous request.',
  ApiError.invalidResponse =>
    'The server returned malformed memory information.',
  _ => 'Trip memories could not be loaded.',
};

class TripMemoriesScreen extends StatefulWidget {
  const TripMemoriesScreen({super.key, required this.plan, required this.api});

  final TripPlanRef plan;
  final TripMemoriesApi api;

  @override
  State<TripMemoriesScreen> createState() => _TripMemoriesScreenState();
}

class _TripMemoriesScreenState extends State<TripMemoriesScreen> {
  late Future<List<TripMemory>> _memories;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _memories = _load();
  }

  Future<List<TripMemory>> _load() async {
    try {
      _loadError = null;
      return await widget.api.list(widget.plan.id);
    } catch (error) {
      _loadError = error;
      return const [];
    }
  }

  void _reload() => setState(() => _memories = _load());

  Future<void> _create() async {
    final created = await Navigator.of(
      context,
    ).pushNamed<bool>(tripMemoryCreateRoute, arguments: widget.plan);
    if (created == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => TripContent(
    title: 'Trip memories',
    children: [
      const Text(
        'Memories are private to the signed-in trip owner. Photo and video attachments are unavailable until a verified media store and upload provider are configured.',
      ),
      WayhunterButton.primary(label: 'Write a memory', onPressed: _create),
      FutureBuilder<List<TripMemory>>(
        future: _memories,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const WayhunterLoadingView(label: 'Loading trip memories');
          }
          if (snapshot.hasError || _loadError != null) {
            final error = snapshot.error ?? _loadError;
            final message = error is ApiException ? _memoryError(error) : null;
            if (error is ApiException &&
                (error.kind == ApiError.unavailable ||
                    error.kind == ApiError.server)) {
              return WayhunterUnavailableView(
                title: 'Memories unavailable',
                message: message,
                action: WayhunterButton.secondary(
                  label: 'Retry',
                  onPressed: _reload,
                ),
              );
            }
            return WayhunterErrorView(
              title: 'Could not load memories',
              message: message,
              onRetry: _reload,
            );
          }
          final memories = snapshot.requireData;
          if (memories.isEmpty) {
            return const WayhunterEmptyView(
              title: 'No saved memories',
              message: 'Create a private text memory for this trip.',
            );
          }
          return Column(
            children: [
              for (final memory in memories)
                Card(
                  child: ListTile(
                    title: Text(
                      memory.caption.isEmpty
                          ? 'Untitled memory'
                          : memory.caption,
                    ),
                    subtitle: Text(
                      '${memory.visibility.label} · ${memory.createdAtUtc.toLocal()}${memory.media == null ? ' · No media attached' : ' · Media metadata available'}',
                    ),
                    onTap: () => Navigator.of(context)
                        .pushNamed<bool>(
                          tripMemoryDetailsRoute,
                          arguments: TripMemoryDetailsArgs(
                            plan: widget.plan,
                            memoryId: memory.id,
                          ),
                        )
                        .then((deleted) {
                          if (deleted == true && mounted) _reload();
                        }),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class TripMemoryCreateScreen extends StatefulWidget {
  const TripMemoryCreateScreen({
    super.key,
    required this.plan,
    required this.api,
  });

  final TripPlanRef plan;
  final TripMemoriesApi api;

  @override
  State<TripMemoryCreateScreen> createState() => _TripMemoryCreateScreenState();
}

class _TripMemoryCreateScreenState extends State<TripMemoryCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _caption = TextEditingController();
  String? _operationId;
  ApiException? _error;
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _operationId ??= _newOperationId();
    });
    try {
      await widget.api.create(
        widget.plan.id,
        operationId: _operationId!,
        caption: _caption.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TripContent(
    title: 'Write a trip memory',
    children: [
      Form(
        key: _formKey,
        child: TextFormField(
          controller: _caption,
          maxLength: 1000,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Memory',
            hintText: 'Write a note about this trip',
          ),
          validator: (value) => (value?.trim().length ?? 0) > 1000
              ? 'Use no more than 1000 characters.'
              : null,
        ),
      ),
      const Text('Visibility: Private'),
      const WayhunterUnavailableView(
        title: 'Media attachments unavailable',
        message:
            'This backend has no configured private media store or upload provider. No media upload will be attempted.',
      ),
      if (_error case final error?)
        WayhunterErrorView(
          title: 'Memory was not confirmed',
          message: _memoryError(error),
          onRetry: _save,
        ),
      WayhunterButton.primary(
        label: _busy ? 'Saving…' : 'Save private memory',
        onPressed: _busy ? null : _save,
      ),
    ],
  );
}

class TripMemoryDetailsScreen extends StatefulWidget {
  const TripMemoryDetailsScreen({
    super.key,
    required this.args,
    required this.api,
  });

  final TripMemoryDetailsArgs args;
  final TripMemoriesApi api;

  @override
  State<TripMemoryDetailsScreen> createState() =>
      _TripMemoryDetailsScreenState();
}

class _TripMemoryDetailsScreenState extends State<TripMemoryDetailsScreen> {
  late Future<TripMemory?> _memory;
  Object? _loadError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _memory = _load();
  }

  Future<TripMemory?> _load() async {
    try {
      _loadError = null;
      return await widget.api.get(widget.args.plan.id, widget.args.memoryId);
    } catch (error) {
      _loadError = error;
      return null;
    }
  }

  void _retry() => setState(() => _memory = _load());

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await showWayhunterConfirmation(
      context,
      title: 'Delete memory?',
      message: 'The server will hide this memory from your trip history.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.delete(widget.args.plan.id, widget.args.memoryId);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_memoryError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TripContent(
    title: 'Memory details',
    children: [
      FutureBuilder<TripMemory?>(
        future: _memory,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const WayhunterLoadingView(label: 'Loading memory');
          }
          if (snapshot.hasError || _loadError != null) {
            final error = snapshot.error ?? _loadError;
            return WayhunterErrorView(
              title: 'Memory unavailable',
              message: error is ApiException ? _memoryError(error) : null,
              onRetry: _retry,
            );
          }
          final memory = snapshot.data;
          if (memory == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(memory.visibility.label),
              Text(memory.caption),
              Text('Created ${memory.createdAtUtc.toLocal()}'),
              if (memory.media != null)
                Text(
                  'Media metadata: ${memory.media!.contentType}, ${memory.media!.contentLength} bytes',
                ),
              const Text('Media content is not served by this mobile API.'),
              WayhunterButton.primary(
                label: _busy ? 'Deleting…' : 'Delete memory',
                onPressed: _busy ? null : _delete,
              ),
            ],
          );
        },
      ),
    ],
  );
}

String _newOperationId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
