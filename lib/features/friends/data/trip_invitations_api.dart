import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/features/friends/domain/trip_invitation.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

/// Scoped to the signed-in shell. Outgoing receipts are kept in memory.
class TripInvitationsApi {
  TripInvitationsApi(this._api, this._session) : _identity = _session.state;

  final ApiClient _api;
  final SessionController _session;
  final SessionState _identity;
  final _outgoing = <String, TripInvitation>{};
  final _running = <String>{};
  final _base = const ['api', 'mobile'];

  bool belongsTo(SessionController session) =>
      identical(_session, session) &&
      identical(session.state, _identity) &&
      session.accessToken != null &&
      _identity.status == SessionStatus.authenticated;

  String? get ownerId =>
      belongsTo(_session) ? _identity.user?.id.toLowerCase() : null;

  List<TripInvitation> sentFor(TripPlanRef plan) => ownerId == null
      ? const []
      : _outgoing.values
            .where((item) => item.plan.id == plan.id.toLowerCase())
            .toList();

  String _id(String id) {
    if (!isInvitationGuid(id)) throw const ApiException(ApiError.rejected);
    return id.toLowerCase();
  }

  String _requireOwner() {
    final owner = ownerId;
    if (owner == null) throw const ApiException(ApiError.unauthorized);
    return owner;
  }

  Future<Object?> _request(
    ApiMethod method,
    List<String> path, [
    Object? body,
  ]) async {
    _requireOwner();
    final response = await _api.request(
      method,
      [..._base, ...path],
      requiresSession: true,
      jsonBody: body,
    );
    _requireOwner();
    return response;
  }

  Future<T> _write<T>(String key, Future<T> Function() action) async {
    if (!_running.add(key)) throw const ApiException(ApiError.conflict);
    try {
      return await action();
    } finally {
      _running.remove(key);
    }
  }

  Future<List<TripInvitation>> pending() async {
    final owner = _requireOwner();
    final response = await _request(ApiMethod.get, [
      'trip-invitations',
      'pending',
    ]);
    if (response is! List<Object?>) {
      throw const ApiException(ApiError.invalidResponse);
    }
    final items = response.map(TripInvitation.fromJson).toList(growable: false);
    if (items.any(
          (item) =>
              item.recipient.id != owner ||
              item.status != InvitationStatus.pending,
        ) ||
        items.map((item) => item.id).toSet().length != items.length) {
      throw const ApiException(ApiError.invalidResponse);
    }
    return items;
  }

  Future<TripInvitation> send(TripPlanRef plan, UserRef recipient) async {
    final planId = _id(plan.id);
    final recipientId = _id(recipient.id);
    final owner = _requireOwner();
    if (owner == recipientId) throw const ApiException(ApiError.rejected);
    return _write('$planId/$recipientId', () async {
      final item = TripInvitation.fromJson(
        await _request(
          ApiMethod.post,
          ['trips', planId, 'invitations'],
          {'recipientUserId': recipientId},
        ),
      );
      if (item.plan.id != planId ||
          item.sender.id != owner ||
          item.recipient.id != recipientId ||
          item.status != InvitationStatus.pending) {
        throw const ApiException(ApiError.invalidResponse);
      }
      _outgoing[item.id] = item;
      return item;
    });
  }

  Future<InvitationDecision> decide(
    TripInvitation item,
    InvitationAction action,
  ) async {
    final id = _id(item.id);
    final owner = _requireOwner();
    final actor = action == InvitationAction.cancel
        ? item.sender.id
        : item.recipient.id;
    if (owner != actor) throw const ApiException(ApiError.forbidden);
    if (item.status != InvitationStatus.pending &&
        item.status != action.status) {
      throw const ApiException(ApiError.conflict);
    }
    return _write(id, () async {
      final result = InvitationDecision.fromJson(
        await _request(ApiMethod.post, ['trip-invitations', id, action.name]),
      );
      if (result.invitationId != id || result.status != action.status) {
        throw const ApiException(ApiError.invalidResponse);
      }
      if (_outgoing[id] case final TripInvitation sent) {
        _outgoing[id] = sent.withStatus(result.status);
      }
      return result;
    });
  }

  Future<bool> removeMember(TripPlanRef plan, UserRef member) async {
    final planId = _id(plan.id);
    final memberId = _id(member.id);
    if (_requireOwner() == memberId) {
      throw const ApiException(ApiError.rejected);
    }
    return _write('$planId/member/$memberId', () async {
      final response = await _request(ApiMethod.delete, [
        'trips',
        planId,
        'members',
        memberId,
      ]);
      if (response case {'removed': final bool removed}) return removed;
      throw const ApiException(ApiError.invalidResponse);
    });
  }
}
