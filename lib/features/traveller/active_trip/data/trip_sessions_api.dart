import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/network/api_dto.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/data/trip_recovery_store.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/domain/trip_session.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_plan.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

typedef _RecoveryKey = ({String owner, String trip});

class _RecoveryOperations {
  final running = <_RecoveryKey>{};
  final failedClears = <_RecoveryKey, String>{};
}

/// Scoped to the authenticated shell, with durable reconciliation markers on Android.
class TripSessionsApi {
  TripSessionsApi(this._api, this._session, {TripRecoveryStore? recoveryStore})
    : _token = _session.accessToken,
      _owner = _session.state.user?.id,
      _state = _session.state,
      _recoveryStore = recoveryStore,
      _operations = recoveryStore == null
          ? _RecoveryOperations()
          : (_storeOperations[recoveryStore] ??= _RecoveryOperations());

  // Bootstrap shares the store across authenticated shells. A replacement
  // adapter must wait for the old operation to release the owner/trip key.
  static final _storeOperations = Expando<_RecoveryOperations>();

  final ApiClient _api;
  final SessionController _session;
  final String? _token;
  final String? _owner;
  final SessionState _state;
  final TripRecoveryStore? _recoveryStore;
  final _RecoveryOperations _operations;
  final _known = <String, TripSession>{};
  final _pending = <String, String>{};
  final _uncertainChanges = <String>{};

  bool belongsTo(SessionController session) =>
      identical(session, _session) &&
      identical(session.state, _state) &&
      _token != null &&
      _owner != null &&
      session.accessToken == _token &&
      session.state.user?.id == _owner;

  TripSession? known(TripPlanRef plan) =>
      belongsTo(_session) ? _known[plan.id.toLowerCase()] : null;

  bool startNeedsVerification(TripPlanRef plan) =>
      belongsTo(_session) &&
      _pending[plan.id.toLowerCase()] == pendingTripStart &&
      known(plan) == null;

  bool finishNeedsVerification(TripPlanRef plan) {
    final marker = _pending[plan.id.toLowerCase()];
    return belongsTo(_session) && marker != null && marker != pendingTripStart;
  }

  Future<void> loadRecovery(TripPlanRef plan) async {
    _requireAccess();
    if (!isTripPlanId(plan.id)) throw const ApiException(ApiError.notFound);
    final key = _recoveryKey(plan);
    await _withRecoveryLock(key, () => _readPending(key));
  }

  static bool needsReconciliation(ApiException error) => switch (error.kind) {
    ApiError.timeout ||
    ApiError.network ||
    ApiError.server ||
    ApiError.invalidResponse ||
    ApiError.conflict => true,
    _ => false,
  };

  Future<TripSession> start(TripPlanRef plan) async {
    _requireAccess();
    final existing = known(plan);
    if (existing != null) return existing;
    return _request(
      plan,
      ApiMethod.post,
      [],
      null,
      (status) => status != TripSessionStatus.finished,
      pendingWrite: pendingTripStart,
    );
  }

  Future<ActiveTripArgs> open(TripPlanRef plan) async {
    _requireAccess();
    if (!isTripPlanId(plan.id)) throw const ApiException(ApiError.notFound);
    final key = _recoveryKey(plan);
    final marker = await _withRecoveryLock(key, () => _readPending(key));
    _requireAccess();
    if (marker == pendingTripStart) {
      final reference = known(plan)?.reference;
      if (reference != null) return reference;
      throw const ApiException(ApiError.conflict);
    }
    if (marker != null) {
      return ActiveTripArgs(plan: plan, session: TripSessionRef(marker));
    }
    return (known(plan) ?? await start(plan)).reference;
  }

  Future<TripSession> recover(ActiveTripArgs args) => _request(
    args.plan,
    ApiMethod.get,
    ['recover'],
    args.session,
    (status) => status != TripSessionStatus.finished,
  );

  Future<TripSession> change(ActiveTripArgs args, TripSessionAction action) =>
      _request(
        args.plan,
        ApiMethod.post,
        [action.name],
        args.session,
        (status) => status == action.result,
        pendingWrite: action == TripSessionAction.finish
            ? args.session.id.toLowerCase()
            : null,
      );

  Future<DateTime> checkIn(TripSession session) async {
    _requireAccess();
    final args = session.reference;
    if (!isTripPlanId(args.plan.id) || !isTripPlanId(args.session.id)) {
      throw const ApiException(ApiError.notFound);
    }
    if (session.status == TripSessionStatus.finished) {
      throw const ApiException(ApiError.conflict);
    }
    final value = await _api.request(
      ApiMethod.post,
      [
        'api',
        'mobile',
        'trips',
        args.plan.id,
        'sessions',
        args.session.id,
        'im-safe',
      ],
      requiresSession: true,
      expectedSuccessStatus: 200,
    );
    _requireAccess();
    if (value
        case {
          'checkInId': final String id,
          'tripPlanId': final String plan,
          'sessionId': final String sessionId,
          'userId': final String user,
          'checkedInAtUtc': final String checkedInAt,
          'created': bool(),
        }
        when isTripPlanId(id) &&
            plan.toLowerCase() == args.plan.id.toLowerCase() &&
            sessionId.toLowerCase() == args.session.id.toLowerCase() &&
            user.toLowerCase() == _owner!.toLowerCase()) {
      final time = decodeApiUtc(checkedInAt);
      if (!time.isBefore(session.startedAtUtc)) return time;
    }
    throw const ApiException(ApiError.invalidResponse);
  }

  _RecoveryKey _recoveryKey(TripPlanRef plan) =>
      (owner: _owner!.toLowerCase(), trip: plan.id.toLowerCase());

  Future<String?> _readPending(_RecoveryKey key) async {
    final store = _recoveryStore;
    if (store == null) return _pending[key.trip];
    final stored = await store.read(key.owner, key.trip);
    _requireAccess();
    final marker = stored ?? _operations.failedClears[key];
    if (marker != null && marker != pendingTripStart && !isTripPlanId(marker)) {
      throw const ApiException(ApiError.invalidResponse);
    }
    if (marker == null) {
      _pending.remove(key.trip);
    } else {
      _pending[key.trip] = marker;
    }
    return marker;
  }

  Future<void> _clearPending(_RecoveryKey key, String marker) async {
    final store = _recoveryStore;
    try {
      await store?.write(key.owner, key.trip, null);
    } on ApiException {
      // Keep blocking this key even if the delete took effect before failing.
      _operations.failedClears[key] = marker;
      if (store != null) {
        try {
          if (await store.read(key.owner, key.trip) == null) {
            await store.write(key.owner, key.trip, marker);
          }
        } on ApiException {
          // The shared guard still blocks mutations while storage is unhealthy.
        }
      }
      rethrow;
    }
    _operations.failedClears.remove(key);
    _pending.remove(key.trip);
  }

  void _requireAccess() {
    if (!belongsTo(_session)) throw const ApiException(ApiError.unauthorized);
  }

  Future<T> _withRecoveryLock<T>(
    _RecoveryKey key,
    Future<T> Function() operation,
  ) async {
    if (!_operations.running.add(key)) {
      throw const ApiException(ApiError.conflict);
    }
    try {
      return await operation();
    } finally {
      _operations.running.remove(key);
    }
  }

  Future<TripSession> _request(
    TripPlanRef plan,
    ApiMethod method,
    List<String> tail,
    TripSessionRef? session,
    bool Function(TripSessionStatus) accepts, {
    String? pendingWrite,
  }) async {
    _requireAccess();
    if (!isTripPlanId(plan.id) ||
        (session != null && !isTripPlanId(session.id))) {
      throw const ApiException(ApiError.notFound);
    }
    final key = _recoveryKey(plan);
    return _withRecoveryLock(key, () async {
      final existingMarker = await _readPending(key);
      final isWrite = method == ApiMethod.post;
      if (isWrite &&
          (existingMarker != null || _uncertainChanges.contains(key.trip))) {
        throw const ApiException(ApiError.conflict);
      }
      if (!isWrite &&
          existingMarker != null &&
          existingMarker != pendingTripStart &&
          existingMarker.toLowerCase() != session?.id.toLowerCase()) {
        throw const ApiException(ApiError.conflict);
      }
      if (pendingWrite != null) {
        await _recoveryStore?.write(key.owner, key.trip, pendingWrite);
        _pending[key.trip] = pendingWrite;
      }
      final TripSession result;
      var dispatched = false;
      try {
        _requireAccess();
        dispatched = true;
        final response = await _api.request(
          method,
          [
            'api',
            'mobile',
            'trips',
            plan.id,
            'sessions',
            if (session != null) session.id,
            ...tail,
          ],
          requiresSession: true,
          expectedSuccessStatus: 200,
        );
        _requireAccess();
        result = TripSession.fromJson(response);
        if (result.reference.plan.id.toLowerCase() != key.trip ||
            (session != null &&
                result.reference.session.id.toLowerCase() !=
                    session.id.toLowerCase()) ||
            !accepts(result.status)) {
          throw const ApiException(ApiError.invalidResponse);
        }
      } on ApiException catch (error) {
        // These HTTP responses are pre-mutation rejections in the trip
        // controller. A 401 may already have expired the dispatching session.
        if (pendingWrite != null &&
            (!dispatched ||
                const {400, 401, 403, 404}.contains(error.statusCode))) {
          await _clearPending(key, pendingWrite);
        } else if (isWrite &&
            belongsTo(_session) &&
            needsReconciliation(error)) {
          _uncertainChanges.add(key.trip);
        }
        rethrow;
      }
      _known[key.trip] = result;
      _uncertainChanges.remove(key.trip);
      final marker = pendingWrite ?? existingMarker;
      if (marker != null) {
        await _clearPending(key, marker);
        _requireAccess();
      }
      return result;
    });
  }
}
