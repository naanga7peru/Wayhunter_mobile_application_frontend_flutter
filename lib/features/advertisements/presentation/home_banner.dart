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

class _HomeBannerState extends State<HomeBanner> {
  late List<HomeAdvertisement> _advertisements = widget.advertisements;
  int _currentIndex = 0;
  Timer? _rotationTimer;
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _startTimers();
  }

  @override
  void didUpdateWidget(covariant HomeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.loadAdvertisements, widget.loadAdvertisements) ||
        oldWidget.rotationInterval != widget.rotationInterval ||
        oldWidget.refreshInterval != widget.refreshInterval) {
      _stopTimers();
      _startTimers();
    }
    if (!identical(oldWidget.advertisements, widget.advertisements)) {
      _setAdvertisements(widget.advertisements);
    }
  }

  void _startTimers() {
    if (_advertisements.length > 1 && widget.rotationInterval > Duration.zero) {
      _rotationTimer = Timer.periodic(widget.rotationInterval, (_) {
        if (!mounted || _advertisements.length < 2) return;
        setState(
          () => _currentIndex = (_currentIndex + 1) % _advertisements.length,
        );
      });
    }
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
    if (_refreshing || !mounted) return;
    _refreshing = true;
    try {
      final advertisements = await loader();
      if (mounted) _setAdvertisements(advertisements);
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
    if (mounted) setState(() {});
  }

  void _syncRotationTimer() {
    if (_advertisements.length < 2 ||
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
