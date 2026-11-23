import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/advertisements/data/home_advertisements_api.dart';

class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key, required this.advertisements});

  final List<HomeAdvertisement> advertisements;

  @override
  Widget build(BuildContext context) {
    if (advertisements.isEmpty) {
      return const WayhunterEmptyView(title: 'No active advertisements');
    }
    final banner = advertisements.first;
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
