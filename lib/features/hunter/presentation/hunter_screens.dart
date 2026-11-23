import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/core/services/device_interfaces.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/hunter/domain/hunter_history.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';
import 'package:wayhunter_mobile/shared/presentation/person2_content.dart';

const hunterAddNewPlaceRoute = 'hunter.addNewPlace';

class HunterHomeScreen extends StatelessWidget {
  const HunterHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Person2Content(
    children: [
      WayhunterSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: WayhunterLayout.medium,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Icon(
                Icons.explore_outlined,
                color: WayhunterColors.moduleInk(ModuleId.hunter),
                size: 36,
              ),
            ),
            const WayhunterHeader(
              title: 'Location Hunter',
              subtitle:
                  'Suggest a place and follow its verification in My Hunts.',
            ),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: WayhunterStatusIndicator(
                label: 'Current district unavailable',
              ),
            ),
            WayhunterButton.primary(
              label: 'Add New Place',
              onPressed: () =>
                  const AppDestination(hunterAddNewPlaceRoute).open(context),
            ),
            WayhunterButton.secondary(
              label: 'My Hunts',
              onPressed: () =>
                  const AppDestination(AppRoutes.myHunts).open(context),
            ),
            WayhunterButton.secondary(
              label: 'Hunter Leaderboard',
              onPressed: () => const AppDestination.leaderboard(
                ModuleId.hunter,
              ).open(context),
            ),
          ],
        ),
      ),
      const WayhunterUnavailableView(
        title: 'Published discoveries unavailable',
        message:
            'Published places will appear here when the discovery service is connected.',
      ),
    ],
  );
}

class AddNewPlaceScreen extends StatefulWidget {
  const AddNewPlaceScreen({super.key});

  @override
  State<AddNewPlaceScreen> createState() => _AddNewPlaceScreenState();
}

class _AddNewPlaceScreenState extends State<AddNewPlaceScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _review() {
    if (!validatePerson2Draft(_form.currentState!)) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WayhunterPageScaffold(
          appBar: AppBar(),
          body: Person2Content(
            children: [
              const WayhunterHeader(
                title: 'Review place details',
                subtitle: 'This draft is local to this screen session.',
              ),
              WayhunterSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name.text.trim(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: WayhunterLayout.small),
                    Text(_description.text.trim()),
                  ],
                ),
              ),
              const _EvidenceRequirements(),
              const WayhunterButton.primary(
                label: 'Submit for review',
                onPressed: null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Person2Content(
      children: [
        const WayhunterHeader(
          title: 'Add New Place',
          subtitle: 'Enter the place details before adding live evidence.',
        ),
        Person2DraftField(
          label: 'Place name',
          hint: 'Enter the name visitors would look for',
          controller: _name,
          validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Enter a place name.' : null,
        ),
        Person2DraftField(
          label: 'Description',
          hint: 'Describe what visitors will find there',
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          controller: _description,
          keyboardType: TextInputType.multiline,
          validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Enter a description.' : null,
        ),
        const _EvidenceRequirements(),
        const _HunterDeviceChecks(),
        WayhunterButton.primary(
          label: 'Review place details',
          onPressed: _review,
        ),
      ],
    ),
  );
}

class _EvidenceRequirements extends StatelessWidget {
  const _EvidenceRequirements();

  @override
  Widget build(BuildContext context) => const WayhunterSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WayhunterHeader(title: 'Location and evidence'),
        SizedBox(height: WayhunterLayout.medium),
        Text('Current district and live GPS: Unavailable'),
        Text('Guided 360° video: Unavailable'),
        Text('Live photo: Unavailable'),
        SizedBox(height: WayhunterLayout.medium),
        Text(
          'Submission requires verified location, live evidence and a connected review service.',
        ),
      ],
    ),
  );
}

class MyHuntsScreen extends StatefulWidget {
  const MyHuntsScreen({super.key, required this.history, this.demoHistory});

  final HunterHistory history;
  final HunterHistory? demoHistory;

  @override
  State<MyHuntsScreen> createState() => _MyHuntsScreenState();
}

class _MyHuntsScreenState extends State<MyHuntsScreen> {
  bool _demo = false;
  Future<List<HuntSummary>>? _hunts;

  @override
  void didUpdateWidget(MyHuntsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_demo && widget.demoHistory == null) {
      _demo = false;
      _hunts = null;
    } else if (_demo
        ? oldWidget.demoHistory != widget.demoHistory
        : oldWidget.history != widget.history) {
      _hunts = null;
    }
  }

  void _load({required bool demo}) => setState(() {
    _demo = demo;
    _hunts = null;
  });

  @override
  Widget build(BuildContext context) => Person2Content(
    children: [
      const WayhunterHeader(
        title: 'My Hunts',
        subtitle: 'Follow the review status of your place submissions.',
      ),
      if (_demo) ...[
        const WayhunterStatusIndicator(
          label: 'Development demo data',
          tone: WayhunterStatusTone.info,
        ),
        WayhunterButton.secondary(
          label: 'Return to My Hunts',
          onPressed: () => _load(demo: false),
        ),
      ],
      FutureBuilder<List<HuntSummary>>(
        future: _hunts ??= (_demo ? widget.demoHistory! : widget.history)
            .load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return WayhunterLoadingView(
              label: _demo ? 'Loading DEMO hunts' : 'Loading hunts',
            );
          }
          if (snapshot.error is HunterHistoryUnavailable) {
            return WayhunterUnavailableView(
              title: 'Hunt history unavailable',
              message:
                  'Your submissions will appear when the Hunter service is connected.',
              action: widget.demoHistory != null
                  ? WayhunterButton.secondary(
                      label: 'View development demo',
                      onPressed: () => _load(demo: true),
                    )
                  : null,
            );
          }
          if (snapshot.hasError) {
            return WayhunterErrorView(
              title: 'Could not load hunts',
              onRetry: () => _load(demo: _demo),
            );
          }
          final hunts = snapshot.requireData;
          if (hunts.isEmpty) {
            return WayhunterEmptyView(
              title: 'No hunts yet',
              message: 'Submitted places will appear here.',
            );
          }
          return Column(
            children: [
              for (final hunt in hunts)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: WayhunterLayout.medium,
                  ),
                  child: WayhunterSurfaceCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      title: Text(hunt.name),
                      subtitle: _HuntStatusIndicator(hunt.status),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openDetails(hunt),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  void _openDetails(HuntSummary hunt) {
    final demo = _demo;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WayhunterPageScaffold(
          appBar: AppBar(),
          body: Person2Content(
            children: [
              const WayhunterHeader(title: 'Hunt details'),
              if (demo)
                const WayhunterStatusIndicator(
                  label: 'Development demo data',
                  tone: WayhunterStatusTone.info,
                ),
              WayhunterSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hunt.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: WayhunterLayout.medium),
                    _HuntStatusIndicator(hunt.status),
                    const SizedBox(height: WayhunterLayout.medium),
                    Text(switch (hunt.status) {
                      HuntStatus.pending => 'Awaiting Admin review.',
                      HuntStatus.approved => 'Review approved.',
                      HuntStatus.rejected =>
                        hunt.reviewReason ?? 'Review reason unavailable.',
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HuntStatusIndicator extends StatelessWidget {
  const _HuntStatusIndicator(this.status);

  final HuntStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      HuntStatus.pending => ('Pending', WayhunterStatusTone.warning),
      HuntStatus.approved => ('Approved', WayhunterStatusTone.success),
      HuntStatus.rejected => ('Rejected', WayhunterStatusTone.danger),
    };
    return WayhunterStatusIndicator(label: label, tone: tone);
  }
}

class _HunterDeviceChecks extends StatefulWidget {
  const _HunterDeviceChecks();

  @override
  State<_HunterDeviceChecks> createState() => _HunterDeviceChecksState();
}

class _HunterDeviceChecksState extends State<_HunterDeviceChecks> {
  bool _busy = false;
  String? _message;

  Future<void> _capture({
    required DevicePermission permission,
    required String label,
    required Future<Object> Function(FoundationServices) read,
  }) async {
    final services = context
        .getInheritedWidgetOfExactType<FoundationServices>();
    if (services == null) {
      setState(() => _message = '$label is unavailable on this device.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      var access = await services.permissions.check(permission);
      if (!mounted) return;
      if (access == DevicePermissionStatus.denied) {
        access = await services.permissions.request(permission);
      }
      if (!mounted) return;
      if (access != DevicePermissionStatus.granted) {
        _message = switch (access) {
          DevicePermissionStatus.denied => '$label permission denied.',
          DevicePermissionStatus.permanentlyDenied =>
            '$label permission blocked. Check device settings.',
          _ => '$label is unavailable on this device.',
        };
        return;
      }
      await read(services);
      _message = '$label captured. Verification and upload are unavailable.';
    } catch (_) {
      _message = 'Could not capture $label. Try again.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: WayhunterLayout.small,
    children: [
      const Text(
        'District validation, nearby duplicate review and restricted-place checks are unavailable.',
      ),
      const Text(
        'For guided 360° evidence, record one slow full turn from a safe position.',
      ),
      if (_message case final message?)
        Semantics(liveRegion: true, child: Text(message)),
      if (_busy)
        const WayhunterLoadingView(label: 'Waiting for device')
      else ...[
        WayhunterButton.secondary(
          label: 'Get current location',
          onPressed: () => _capture(
            permission: DevicePermission.location,
            label: 'GPS location',
            read: (services) => services.location.read(),
          ),
        ),
        WayhunterButton.secondary(
          label: 'Record guided 360° video',
          onPressed: () => _capture(
            permission: DevicePermission.camera,
            label: 'Live video',
            read: (services) => services.capture.recordVideo(),
          ),
        ),
        WayhunterButton.secondary(
          label: 'Take live photo',
          onPressed: () => _capture(
            permission: DevicePermission.camera,
            label: 'Live photo',
            read: (services) => services.capture.takePhoto(),
          ),
        ),
      ],
    ],
  );
}
