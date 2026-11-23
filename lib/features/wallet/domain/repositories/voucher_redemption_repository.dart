import '../voucher_redemption.dart';

abstract interface class VoucherRedemptionRepository {
  VoucherRedemptionIntent prepareCreate(String offerId);

  /// A transport or decoding failure can leave the outcome unknown. Reconcile
  /// by request ID before deciding whether to retry with the original intent.
  Future<VoucherRedemptionRequest> create(VoucherRedemptionIntent intent);

  /// Supply an ID from an authorized server workflow or the original create
  /// intent when reconciling. The server checks ownership on every read.
  Future<VoucherRedemptionRequest> readRequest(String requestId);

  Future<VoucherRedemptionRequest> cancel(String requestId, String reason);

  Future<IssuedVoucher> readIssuedVoucher(String requestId);
}
