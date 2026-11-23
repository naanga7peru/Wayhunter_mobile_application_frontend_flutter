import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';

/// Owns one request per mounted panel and reloads only on explicit retry.
class AccountReadPanel<T> extends StatefulWidget {
  const AccountReadPanel({
    super.key,
    required this.label,
    required this.load,
    required this.content,
  });

  final String label;
  final Future<T> Function() load;
  final Widget Function(T) content;

  @override
  State<AccountReadPanel<T>> createState() => _AccountReadPanelState<T>();
}

class _AccountReadPanelState<T> extends State<AccountReadPanel<T>> {
  late Future<({T? data, Object? error})> _response = _load();

  Future<({T? data, Object? error})> _load() async {
    try {
      return (data: await widget.load(), error: null);
    } on ApiException catch (error) {
      return (data: null, error: error);
    }
  }

  void _retry() {
    final response = _load();
    setState(() {
      _response = response;
    });
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<({T? data, Object? error})>(
        future: _response,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return WayhunterLoadingView(label: 'Loading ${widget.label}');
          }
          final response = snapshot.requireData;
          if (response.error != null) {
            return WayhunterErrorView(
              title: 'Could not load ${widget.label}',
              message: switch (response.error) {
                ApiException(kind: ApiError.network || ApiError.timeout) =>
                  'Check your connection and try again.',
                ApiException(
                  kind: ApiError.unauthorized || ApiError.forbidden,
                ) =>
                  'Your account cannot access this information.',
                ApiException(kind: ApiError.unavailable || ApiError.server) =>
                  'This service is unavailable right now.',
                _ => 'The service did not return the expected information.',
              },
              onRetry: _retry,
            );
          }
          return widget.content(response.data as T);
        },
      );
}
