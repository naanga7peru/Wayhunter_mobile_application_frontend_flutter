import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/advertisements/data/home_advertisements_api.dart';

class HomeBanner extends StatefulWidget {
  const HomeBanner({
    super.key,
    required this.advertisements,
    this.loadAdvertisements,
    this.rotationInterval = const Duration(seconds: 3),
    this.refreshInterval = const Duration(seconds: 15),
  });

  final List<HomeAdvertisement> advertisements;
  final Future<List<HomeAdvertisement>> Function()? loadAdvertisements;
  final Duration rotationInterval;
  final Duration refreshInterval;

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> with WidgetsBindingObserver {
  late List<HomeAdvertisement> _advertisements = widget.advertisements;
  int _currentIndex = 0;
  Timer? _rotationTimer;
  Timer? _refreshTimer;
  bool _refreshing = false;
  bool _routeIsCurrent = false;
  late bool _resumed;
  int _sourceVersion = 0;

  bool get _visible => _routeIsCurrent && _resumed;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _resumed =
        (binding.lifecycleState ?? AppLifecycleState.resumed) ==
        AppLifecycleState.resumed;
    binding.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasVisible = _visible;
    _routeIsCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (wasVisible != _visible) _restartTimers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasVisible = _visible;
    _resumed = state == AppLifecycleState.resumed;
    if (wasVisible != _visible) _restartTimers();
  }

  @override
  void didUpdateWidget(covariant HomeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final loaderChanged =
        oldWidget.loadAdvertisements != widget.loadAdvertisements;
    final dataChanged = !identical(
      oldWidget.advertisements,
      widget.advertisements,
    );
    if (loaderChanged || dataChanged) {
      _sourceVersion++;
      _setAdvertisements(widget.advertisements);
    }
    if (loaderChanged ||
        oldWidget.rotationInterval != widget.rotationInterval ||
        oldWidget.refreshInterval != widget.refreshInterval) {
      _restartTimers();
    }
  }

  void _restartTimers() {
    _stopTimers();
    if (!_visible) return;
    _syncRotationTimer();
    if (widget.loadAdvertisements case final loader?
        when widget.refreshInterval > Duration.zero) {
      _refreshTimer = Timer.periodic(widget.refreshInterval, (_) {
        unawaited(_refresh(loader));
      });
    }
  }

  void _stopTimers() {
    _rotationTimer?.cancel();
    _refreshTimer?.cancel();
    _rotationTimer = null;
    _refreshTimer = null;
  }

  Future<void> _refresh(
    Future<List<HomeAdvertisement>> Function() loader,
  ) async {
    if (_refreshing || !mounted || !_visible) return;
    _refreshing = true;
    final sourceVersion = _sourceVersion;
    try {
      final advertisements = await loader();
      if (mounted && sourceVersion == _sourceVersion) {
        setState(() => _setAdvertisements(advertisements));
      }
    } catch (_) {
      // Keep the last successful response visible when refresh is unavailable.
    } finally {
      _refreshing = false;
    }
  }

  void _setAdvertisements(List<HomeAdvertisement> advertisements) {
    _advertisements = advertisements;
    _currentIndex = 0;
    _syncRotationTimer();
  }

  void _syncRotationTimer() {
    if (!_visible ||
        _advertisements.length < 2 ||
        widget.rotationInterval <= Duration.zero) {
      _rotationTimer?.cancel();
      _rotationTimer = null;
      return;
    }
    _rotationTimer ??= Timer.periodic(widget.rotationInterval, (_) {
      if (!mounted || _advertisements.length < 2) return;
      setState(
        () => _currentIndex = (_currentIndex + 1) % _advertisements.length,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_advertisements.isEmpty) {
      return const WayhunterEmptyView(title: 'No active advertisements');
    }
    final banner = _advertisements[_currentIndex];
    return WayhunterSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          const Text('Advertisement'),
          Text(banner.title, style: Theme.of(context).textTheme.titleMedium),
          Image.network(
            banner.imageUrl.toString(),
            height: 120,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                const Text('Advertisement image unavailable'),
          ),
        ],
      ),
    );
  }
}
