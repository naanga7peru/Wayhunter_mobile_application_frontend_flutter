enum VoucherRequestStatus { pending, approved, rejected, cancelled }

enum VoucherIssuanceStatus { unissued, failed, issued, used, expired }

/// Reuse this intent for every retry of the same logical create operation.
/// Its request ID can also be used to reconcile an uncertain outcome.
abstract interface class VoucherRedemptionIntent {
  String get requestId;
  String get offerId;
}

typedef VoucherRedemptionRequest = ({
  String requestId,
  String offerId,
  String ownerUserId,
  String ownerName,
  int costCoins,
  VoucherRequestStatus status,
  DateTime requestedAtUtc,
  DateTime? decidedAtUtc,
  String? decisionReason,
});

/// An owner-scoped response. Read sensitive values only when needed and do
/// not copy them into persistent storage, logs or navigation arguments.
abstract interface class IssuedVoucher {
  String get requestId;
  VoucherIssuanceStatus get status;
  num get referenceValueLkr;
  DateTime? get issuedAtUtc;
  DateTime? get expiresAtUtc;
  DateTime? get usedAtUtc;
  String? get voucherCode;
  String? get qrPayload;
}

class VoucherMutationsDisabled implements Exception {
  const VoucherMutationsDisabled();
}
