import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/notifications/data/notifications_api.dart';
import 'package:wayhunter_mobile/features/notifications/domain/notification_models.dart';
import 'package:wayhunter_mobile/features/traveller/planning/data/trip_plans_api.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/trip_plan_widgets.dart';

const notificationsRoute = 'notifications.home';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    required this.api,
    required this.plans,
  });

  final NotificationsApi api;
  final TripPlansApi plans;

  Future<void> _details(BuildContext context, InboxItem item) async {
    final id = item.tripPlanId;
    await showDialog<void>(
      context: context,
      builder: (_) => _NotificationDetails(
        load: () async {
          if (id == null) return null;
          api.requireCurrent();
          final plan = await plans.get(id);
          api.requireCurrent();
          if (DateUtils.dateOnly(
            DateTime.now(),
          ).isAfter(plan.information.end)) {
            return null;
          }
          return TripSummary(info: plan.information);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => TripContent(
    title: 'Notifications',
    children: [
      WayhunterButton.secondary(
        label: 'Notification preferences',
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => WayhunterPageScaffold(
              appBar: AppBar(),
              body: NotificationPreferencesScreen(api: api),
            ),
          ),
        ),
      ),
      _ServerPanel<InboxPage>(
        label: 'notifications',
        read: api.inbox,
        content: (context, page, run) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text('${page.unreadCount} unread'),
            if (page.items.isEmpty)
              const WayhunterEmptyView(title: 'No notifications'),
            for (final item in page.items)
              WayhunterSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(item.createdAtUtc.toLocal()),
                    ),
                    Text(item.isRead ? 'Read' : 'Unread'),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: () => _details(context, item),
                          child: const Text('View details'),
                        ),
                        if (!item.isRead)
                          TextButton(
                            onPressed: run == null
                                ? null
                                : () => run(() => api.markRead(item.eventId)),
                            child: const Text('Mark as read'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key, required this.api});

  final NotificationsApi api;

  @override
  Widget build(BuildContext context) => TripContent(
    title: 'Notification preferences',
    children: [
      const Text(
        'Choose which categories may send push notifications. Your inbox remains available.',
      ),
      _ServerPanel<List<NotificationPreference>>(
        label: 'preferences',
        read: api.preferences,
        content: (_, choices, run) => choices.isEmpty
            ? const WayhunterEmptyView(
                title: 'No notification preferences available',
              )
            : Column(
                children: [
                  for (final preference in choices)
                    SwitchListTile(
                      title: Text(preference.category.label),
                      value: preference.pushEnabled,
                      onChanged: run == null
                          ? null
                          : (enabled) => run(
                              () => api.updatePreference(
                                preference.category,
                                enabled,
                              ),
                            ),
                    ),
                ],
              ),
      ),
    ],
  );
}

typedef _RunWrite = void Function(Future<void> Function());

class _ServerPanel<T extends Object> extends StatefulWidget {
  const _ServerPanel({
    required this.label,
    required this.read,
    required this.content,
  });

  final String label;
  final Future<T> Function() read;
  final Widget Function(BuildContext, T, _RunWrite?) content;

  @override
  State<_ServerPanel<T>> createState() => _ServerPanelState<T>();
}

class _ServerPanelState<T extends Object> extends State<_ServerPanel<T>> {
  T? _data;
  ApiException? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([Future<void> Function()? write]) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (write != null) await write();
      final result = await widget.read();
      if (mounted) setState(() => _data = result);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        if (error.kind == ApiError.unauthorized ||
            error.kind == ApiError.forbidden) {
          _data = null;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final data = _data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        if (_busy) WayhunterLoadingView(label: 'Loading ${widget.label}'),
        if (error != null)
          WayhunterErrorView(
            title: 'Could not refresh ${widget.label}',
            message: switch (error.kind) {
              ApiError.unauthorized || ApiError.forbidden =>
                'Your account cannot access this information.',
              ApiError.unavailable ||
              ApiError.server => 'The notification service is unavailable.',
              ApiError.network ||
              ApiError.timeout => 'Check your connection and try again.',
              ApiError.notFound => 'This item is no longer available.',
              _ =>
                'The request could not be confirmed. Refresh before making another change.',
            },
            onRetry: _load,
          )
        else if (!_busy)
          WayhunterButton.secondary(label: 'Refresh', onPressed: _load),
        if (data != null)
          widget.content(context, data, _busy || error != null ? null : _load),
      ],
    );
  }
}

class _NotificationDetails extends StatefulWidget {
  const _NotificationDetails({required this.load});
  final Future<Widget?> Function() load;

  @override
  State<_NotificationDetails> createState() => _NotificationDetailsState();
}

class _NotificationDetailsState extends State<_NotificationDetails> {
  late final _detail = widget.load();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Notification details'),
    scrollable: true,
    content: FutureBuilder<Widget?>(
      future: _detail,
      builder: (_, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const WayhunterLoadingView(
            label: 'Checking notification destination',
          );
        }
        return snapshot.data ??
            const Text('This notification destination is unavailable.');
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  );
}
