import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_plan.dart';

String tripError(Object? error) => switch (error) {
  ApiException(kind: ApiError.unauthorized || ApiError.forbidden) =>
    'Your account cannot access this trip. Sign in again if your session ended.',
  ApiException(kind: ApiError.notFound) => 'This trip is unavailable.',
  ApiException(kind: ApiError.conflict) =>
    'The saved trip changed or is no longer editable. Reload the plan before making more changes.',
  ApiException(kind: ApiError.unavailable) =>
    'This trip operation is unavailable.',
  ApiException(kind: ApiError.invalidResponse) =>
    'The server returned an invalid trip response.',
  ApiException(kind: ApiError.network || ApiError.timeout || ApiError.server) =>
    'Could not confirm the result from Wayhunter.',
  _ => 'Wayhunter could not accept the trip information.',
};

bool tripMutationUncertain(Object error) =>
    error is ApiException &&
    switch (error.kind) {
      ApiError.network ||
      ApiError.timeout ||
      ApiError.server ||
      ApiError.invalidResponse => true,
      _ => false,
    };

class TripContent extends StatelessWidget {
  const TripContent({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: WayhunterLayout.contentWidth,
        ),
        child: ListView(
          padding: const EdgeInsets.all(WayhunterLayout.pagePadding),
          children: [
            WayhunterHeader(title: title),
            for (final child in children) ...[
              const SizedBox(height: WayhunterLayout.medium),
              child,
            ],
          ],
        ),
      ),
    ),
  );
}

class TripRead<T> extends StatelessWidget {
  const TripRead({
    super.key,
    required this.future,
    required this.onRetry,
    required this.content,
  });

  final Future<T> future;
  final VoidCallback onRetry;
  final Widget Function(T) content;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (_, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const WayhunterLoadingView(label: 'Loading trip plans');
      }
      if (snapshot.hasError) {
        return WayhunterErrorView(
          title: 'Could not load trip plans',
          message: tripError(snapshot.error),
          onRetry: onRetry,
        );
      }
      return content(snapshot.requireData);
    },
  );
}

class TripSummary extends StatelessWidget {
  const TripSummary({super.key, required this.info});

  final TripInformation info;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(info.name, style: Theme.of(context).textTheme.titleLarge),
      Text('${tripDate(info.start)} to ${tripDate(info.end)}'),
      Text('${info.vehicle} · ${info.headcount} travelers'),
      Text('Budget LKR ${info.budget}'),
    ],
  );
}
