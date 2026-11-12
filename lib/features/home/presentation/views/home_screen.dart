import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/wayhunter_module.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onSelectModule});
  final ValueChanged<WayhunterModule> onSelectModule;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          children: [
            Text('WAYHUNTER', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            const Text('Sri Lanka exploration — development starter'),
            const SizedBox(height: 20),
            const Text('Choose a module'),
            const SizedBox(height: 10),
            for (final module in WayhunterModule.values)
              Card(
                child: ListTile(
                  title: Text(module.title),
                  subtitle: Text('Owner: ${module.owner} · UI scaffold only'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onSelectModule(module),
                ),
              ),
            const SizedBox(height: 20),
            const Text('Scenic Home assets, live API calls and verified functionality '
                'will be implemented by their owners.'),
          ],
        ),
      );
}
