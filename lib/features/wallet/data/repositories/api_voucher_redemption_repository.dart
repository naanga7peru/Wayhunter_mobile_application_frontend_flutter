import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';

import '../../domain/repositories/voucher_redemption_repository.dart';
import '../../domain/voucher_redemption.dart';

/// Construct with the same session used by the ApiClient. Obtain a fresh
/// adapter for each authenticated session.
class ApiVoucherRedemptionRepository implements VoucherRedemptionRepository {
  ApiVoucherRedemptionRepository(ApiClient api, SessionController session)
    : this._(api, session, false);

  @visibleForTesting
  ApiVoucherRedemptionRepository.withMutationsForTesting(
    ApiClient api,
    SessionController session,
  ) : this._(api, session, true);

  ApiVoucherRedemptionRepository._(
    this._api,
    this._session,
    this._mutationsEnabled,
  ) : _boundSession = _session.state;

  final ApiClient _api;
  final SessionController _session;
  final SessionState _boundSession;
  final bool _mutationsEnabled;
  final _inFlight =
      <
        String,
        ({
          String action,
          String payload,
          Future<VoucherRedemptionRequest> result,
        })
      >{};
  final _completed = <(String, String)>{};

  static const _base = [
    'api',
    'mobile',
    'coins-wallet',
    'vouchers',
    'requests',
  ];
  static const _unauthorized = ApiException(ApiError.unauthorized);
  static const _invalid = ApiException(ApiError.invalidResponse);
  static final _guid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final _utc = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|\+00:00)$',
  );

  bool get _isCurrent =>
      identical(_session.state, _boundSession) &&
      _boundSession.status == SessionStatus.authenticated &&
      _session.accessToken != null;

  void _requireSession() {
    if (!_isCurrent) throw _unauthorized;
  }

  void _requireMutations() {
    if (!_mutationsEnabled) throw const VoucherMutationsDisabled();
    _requireSession();
  }

  @override
  VoucherRedemptionIntent prepareCreate(String offerId) {
    _requireSession();
    return _CreateIntent(_boundSession, _newRequestId(), _inputId(offerId));
  }

  @override
  Future<VoucherRedemptionRequest> create(
    VoucherRedemptionIntent intent,
  ) async {
    _requireMutations();
    if (intent is! _CreateIntent || !identical(intent.session, _boundSession)) {
      throw _unauthorized;
    }
    final result = await _mutate(
      intent.requestId,
      'create',
      intent.offerId,
      () async {
        final result = await _request(
          ApiMethod.post,
          _base,
          intent.requestId,
          body: {'requestId': intent.requestId, 'offerId': intent.offerId},
        );
        if (result.offerId != intent.offerId) throw _invalid;
        return result;
      },
    );
    _requireSession();
    if (result.offerId != intent.offerId) throw _invalid;
    return result;
  }

  @override
  Future<VoucherRedemptionRequest> readRequest(String requestId) async {
    final id = _inputId(requestId);
    final result = await _request(ApiMethod.get, [..._base, id], id);
    _requireSession();
    _completed.add((id, 'create'));
    if (result.status == VoucherRequestStatus.cancelled) {
      _completed.add((id, 'cancel'));
    }
    return result;
  }

  @override
  Future<VoucherRedemptionRequest> cancel(
    String requestId,
    String reason,
  ) async {
    _requireMutations();
    final id = _inputId(requestId);
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError('Cancellation reason required.');
    }
    return _mutate(id, 'cancel', trimmedReason, () async {
      final result = await _request(
        ApiMethod.post,
        [..._base, id, 'cancel'],
        id,
        body: {'reason': trimmedReason},
      );
      if (result.status != VoucherRequestStatus.cancelled) throw _invalid;
      return result;
    });
  }

  Future<VoucherRedemptionRequest> _mutate(
    String id,
    String action,
    String payload,
    Future<VoucherRedemptionRequest> Function() send,
  ) {
    final active = _inFlight[id];
    if (active != null) {
      if (active.action == action && active.payload == payload) {
        return active.result;
      }
      throw const ApiException(ApiError.conflict);
    }
    if (_completed.contains((id, action))) return readRequest(id);

    final result = Future.microtask(send)
        .then((value) {
          _requireSession();
          _completed.add((id, action));
          return value;
        })
        .whenComplete(() => _inFlight.remove(id));
    _inFlight[id] = (action: action, payload: payload, result: result);
    return result;
  }

  @override
  Future<IssuedVoucher> readIssuedVoucher(String requestId) async {
    final id = _inputId(requestId);
    final dto = await _call(ApiMethod.get, [..._base, id, 'issued-voucher']);
    _requireSession();
    if (_responseId(dto, 'requestId') != id) throw _invalid;
    final status = switch (_field<int>(dto, 'status')) {
      1 => VoucherIssuanceStatus.unissued,
      2 => VoucherIssuanceStatus.failed,
      3 => VoucherIssuanceStatus.issued,
      4 => VoucherIssuanceStatus.used,
      5 => VoucherIssuanceStatus.expired,
      _ => throw _invalid,
    };
    final code = _nullable<String>(dto, 'voucherCode');
    final qr = _nullable<String>(dto, 'qrPayload');
    _nullable<String>(dto, 'sampleImageReference');
    final reveal =
        status == VoucherIssuanceStatus.issued ||
        status == VoucherIssuanceStatus.used;
    if (reveal &&
        (code == null ||
            code.trim().isEmpty ||
            qr == null ||
            qr.trim().isEmpty)) {
      throw _invalid;
    }
    return _IssuedVoucher(
      requestId: id,
      status: status,
      referenceValueLkr: _field<num>(dto, 'referenceValueLkr'),
      issuedAtUtc: _nullableTime(dto, 'issuedAtUtc'),
      expiresAtUtc: _nullableTime(dto, 'expiresAtUtc'),
      usedAtUtc: _nullableTime(dto, 'usedAtUtc'),
      code: reveal ? code : null,
      qr: reveal ? qr : null,
      isCurrent: () => _isCurrent,
    );
  }

  Future<VoucherRedemptionRequest> _request(
    ApiMethod method,
    List<String> path,
    String id, {
    Map<String, String>? body,
  }) async {
    final dto = await _call(method, path, body: body);
    _requireSession();
    final owner = _field<String>(dto, 'ownerUserId');
    if (owner != _boundSession.user?.id ||
        _responseId(dto, 'requestId') != id) {
      throw _invalid;
    }
    return (
      requestId: id,
      offerId: _responseId(dto, 'offerId'),
      ownerUserId: owner,
      ownerName: _field<String>(dto, 'ownerName'),
      costCoins: _field<int>(dto, 'costCoins'),
      status: switch (_field<int>(dto, 'status')) {
        1 => VoucherRequestStatus.pending,
        2 => VoucherRequestStatus.approved,
        3 => VoucherRequestStatus.rejected,
        4 => VoucherRequestStatus.cancelled,
        _ => throw _invalid,
      },
      requestedAtUtc: _time(_field<String>(dto, 'requestedAtUtc')),
      decidedAtUtc: _nullableTime(dto, 'decidedAtUtc'),
      decisionReason: _nullable<String>(dto, 'decisionReason'),
    );
  }

  Future<Map<String, dynamic>> _call(
    ApiMethod method,
    List<String> path, {
    Map<String, String>? body,
  }) async {
    _requireSession();
    try {
      final response = await _api.request(
        method,
        path,
        jsonBody: body,
        requiresSession: true,
      );
      if (response is! Map<String, dynamic>) throw _invalid;
      return response;
    } finally {
      _requireSession();
    }
  }

  static T _field<T>(Map<String, dynamic> dto, String key) =>
      _nullable<T>(dto, key) ?? (throw _invalid);

  static T? _nullable<T>(Map<String, dynamic> dto, String key) {
    final value = dto[key];
    if (!dto.containsKey(key) || (value != null && value is! T)) throw _invalid;
    return value as T?;
  }

  static String _inputId(String input) {
    final id = input.toLowerCase();
    if (!_validId(id)) throw ArgumentError('Invalid voucher UUID.');
    return id;
  }

  static String _responseId(Map<String, dynamic> dto, String key) {
    final id = _field<String>(dto, key).toLowerCase();
    if (!_validId(id)) throw _invalid;
    return id;
  }

  static bool _validId(String id) =>
      id.length == 36 &&
      _guid.hasMatch(id) &&
      id != '00000000-0000-0000-0000-000000000000';

  static DateTime? _nullableTime(Map<String, dynamic> dto, String key) {
    final value = _nullable<String>(dto, key);
    return value == null ? null : _time(value);
  }

  static DateTime _time(String value) {
    if (!_utc.hasMatch(value)) throw _invalid;
    final parsed = DateTime.tryParse(value);
    // Dart normalizes out-of-range date parts. Compare the fixed-width prefix.
    if (parsed == null ||
        parsed.toIso8601String().substring(0, 19) != value.substring(0, 19)) {
      throw _invalid;
    }
    return parsed;
  }

  static String _newRequestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class _CreateIntent implements VoucherRedemptionIntent {
  const _CreateIntent(this.session, this.requestId, this.offerId);
  final SessionState session;
  @override
  final String requestId;
  @override
  final String offerId;
}

class _IssuedVoucher implements IssuedVoucher {
  const _IssuedVoucher({
    required this.requestId,
    required this.status,
    required this.referenceValueLkr,
    required this.issuedAtUtc,
    required this.expiresAtUtc,
    required this.usedAtUtc,
    required String? code,
    required String? qr,
    required bool Function() isCurrent,
  }) : _code = code,
       _qr = qr,
       _isCurrent = isCurrent;

  @override
  final String requestId;
  @override
  final VoucherIssuanceStatus status;
  @override
  final num referenceValueLkr;
  @override
  final DateTime? issuedAtUtc;
  @override
  final DateTime? expiresAtUtc;
  @override
  final DateTime? usedAtUtc;

  final String? _code;
  final String? _qr;
  final bool Function() _isCurrent;

  @override
  String? get voucherCode => _isCurrent() ? _code : null;

  @override
  String? get qrPayload => _isCurrent() ? _qr : null;
}
