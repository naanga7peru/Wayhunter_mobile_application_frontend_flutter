import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/friends/data/trip_invitations_api.dart';
import 'package:wayhunter_mobile/features/friends/domain/trip_invitation.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/trip_plan_widgets.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

const friendsRoute = 'friends.home';
const tripFriendsRoute = 'friends.trip';

String _invitationError(ApiException error) => switch (error.kind) {
  ApiError.unauthorized => 'Sign in again to access trip invitations.',
  ApiError.forbidden =>
    'This account is not allowed to perform that invitation action.',
  ApiError.notFound => 'The trip or invitation is no longer available.',
  ApiError.conflict =>
    'The invitation may have changed, or the recipient is not eligible.',
  ApiError.server || ApiError.unavailable =>
    'Trip invitations are unavailable from the server right now.',
  ApiError.network || ApiError.timeout =>
    'The server response could not be confirmed. Check your connection.',
  _ => 'The server could not confirm this invitation request.',
};

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, required this.api, this.trip});

  final TripInvitationsApi api;
  final TripPlanRef? trip;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _recipient = TextEditingController();
  List<TripInvitation>? _pending;
  String? _loadError;
  String? _sendMessage;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _recipient.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _pending = null;
      _loadError = null;
    });
    try {
      final pending = await widget.api.pending();
      if (mounted) setState(() => _pending = pending);
    } on ApiException catch (error) {
      if (mounted) setState(() => _loadError = _invitationError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final id = _recipient.text.trim();
    if (!isInvitationGuid(id) || id.toLowerCase() == widget.api.ownerId) {
      setState(
        () => _sendMessage = 'Enter the User ID of another Wayhunter account.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _sendMessage = null;
    });
    try {
      await widget.api.send(widget.trip!, UserRef(id));
      if (!mounted) return;
      _recipient.clear();
      setState(
        () => _sendMessage =
            'Invitation sent. The server confirmed it is pending.',
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _sendMessage = _invitationError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _open(TripInvitation item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WayhunterPageScaffold(
          appBar: AppBar(),
          body: _InvitationDetails(api: widget.api, item: item),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Widget _invitation(TripInvitation item, {required bool sent}) =>
      WayhunterSurfaceCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          title: Text(sent ? item.recipient.id : 'Trip invitation'),
          subtitle: Text(
            sent
                ? 'Last confirmed: ${item.status.label}'
                : 'From ${item.sender.id}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _sending ? null : () => _open(item),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final pending = _pending;
    return PopScope(
      canPop: !_sending,
      child: TripContent(
        title: 'Friends',
        children: [
          const Text(
            'Followers, Following, follow requests, blocking, contact discovery, public profiles, and user search are unavailable.',
          ),
          if (trip == null)
            const Text(
              'Open Add Friends from a saved trip to send an invitation.',
            )
          else ...[
            const WayhunterHeader(title: 'Invite to this trip'),
            const Text(
              'Enter a known Wayhunter User ID. The server checks eligibility before sending.',
            ),
            WayhunterTextField(
              label: 'Recipient User ID',
              controller: _recipient,
              enabled: !_sending,
            ),
            WayhunterButton.primary(
              label: 'Send invitation',
              onPressed: _sending ? null : _send,
            ),
            if (_sending)
              const WayhunterLoadingView(label: 'Sending invitation'),
            if (_sendMessage case final message?)
              Semantics(liveRegion: true, child: Text(message)),
            const WayhunterHeader(title: 'Invitations sent here'),
            const Text(
              'Only receipts confirmed in this sign-in session are shown. A trip participant roster is unavailable.',
            ),
            for (final item in widget.api.sentFor(trip))
              _invitation(item, sent: true),
          ],
          const WayhunterHeader(title: 'Pending trip invitations'),
          if (_loading)
            const WayhunterLoadingView(label: 'Loading invitations')
          else if (_loadError case final error?)
            WayhunterErrorView(
              title: 'Could not load invitations',
              message: error,
              onRetry: _load,
            )
          else if (pending != null) ...[
            if (pending.isEmpty)
              const WayhunterEmptyView(title: 'No pending trip invitations'),
            for (final item in pending) _invitation(item, sent: false),
            WayhunterButton.secondary(
              label: 'Refresh invitations',
              onPressed: _load,
            ),
          ],
        ],
      ),
    );
  }
}

class _InvitationDetails extends StatefulWidget {
  const _InvitationDetails({required this.api, required this.item});
  final TripInvitationsApi api;
  final TripInvitation item;

  @override
  State<_InvitationDetails> createState() => _InvitationDetailsState();
}

class _InvitationDetailsState extends State<_InvitationDetails> {
  InvitationDecision? _decision;
  String? _error;
  bool _busy = false;

  Future<void> _decide(InvitationAction action) async {
    if (_busy || _decision != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.decide(widget.item, action);
      if (mounted) setState(() => _decision = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _invitationError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final status = _decision?.status ?? item.status;
    final owner = widget.api.ownerId;
    final actions = status != InvitationStatus.pending
        ? <InvitationAction>[]
        : [
            if (item.recipient.id == owner) ...[
              InvitationAction.accept,
              InvitationAction.reject,
            ],
            if (item.sender.id == owner) InvitationAction.cancel,
          ];
    return PopScope(
      canPop: !_busy,
      child: TripContent(
        title: 'Invitation details',
        children: [
          Text(status.label),
          Text('Trip ID ${item.plan.id}'),
          Text('Sender ${item.sender.id}'),
          Text('Recipient ${item.recipient.id}'),
          Text(
            MaterialLocalizations.of(
              context,
            ).formatMediumDate(item.createdAtUtc.toLocal()),
          ),
          if (_decision?.memberId case final member?) ...[
            const Text('Trip membership confirmed'),
            Text('Member ID $member'),
            const Text('GPS sharing requires separate consent.'),
          ],
          if (_busy) const WayhunterLoadingView(label: 'Updating invitation'),
          if (_error case final message?)
            Semantics(liveRegion: true, child: Text(message)),
          for (final action in actions)
            WayhunterButton.secondary(
              label: action.label,
              onPressed: _busy ? null : () => _decide(action),
            ),
        ],
      ),
    );
  }
}
