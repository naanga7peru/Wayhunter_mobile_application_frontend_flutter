import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/network/api_dto.dart';
import 'package:wayhunter_mobile/core/network/session_api.dart';

import '../../domain/repositories/wallet_reader.dart';

class ApiWalletReader implements WalletReader {
  const ApiWalletReader(this._api);

  final SessionApi _api;
  static const _base = ['api', 'mobile', 'coins-wallet'];
  static const _invalid = ApiException(ApiError.invalidResponse);

  @override
  Future<LiveWalletBalance?> readBalance() async {
    final Object? response;
    try {
      response = await _get(['me']);
    } on ApiException catch (error) {
      if (error.kind == ApiError.notFound) return null;
      rethrow;
    }
    final dto = _object(response);
    return (
      posted: _field<int>(dto, 'postedCoins'),
      reserved: _field<int>(dto, 'reservedCoins'),
      spendable: _field<int>(dto, 'spendableCoins'),
      lifetimeEarned: _field<int>(dto, 'lifetimeEarnedCoins'),
    );
  }

  @override
  Future<WalletTransactionPage> readTransactions({
    int page = 1,
    int pageSize = 20,
    bool rewardsOnly = false,
  }) async {
    final dto = _object(
      await _get(
        ['me', 'transactions'],
        {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
          if (rewardsOnly) 'kind': 'Reward',
        },
      ),
    );
    final responsePage = _field<int>(dto, 'page');
    final responsePageSize = _field<int>(dto, 'pageSize');
    final totalCount = _field<int>(dto, 'totalCount');
    final items = _field<List<Object?>>(dto, 'items');
    if (responsePage != page ||
        responsePage < 1 ||
        responsePageSize < 1 ||
        responsePageSize > 100 ||
        totalCount < 0 ||
        items.length > responsePageSize ||
        items.length > totalCount) {
      throw _invalid;
    }
    final entries = List<LiveWalletTransaction>.unmodifiable(
      items.map(_transaction),
    );
    if (rewardsOnly &&
        entries.any((entry) => entry.kind != WalletTransactionKind.reward)) {
      throw _invalid;
    }
    return (
      page: responsePage,
      pageSize: responsePageSize,
      totalCount: totalCount,
      items: entries,
    );
  }

  static LiveWalletTransaction _transaction(Object? value) {
    final dto = _object(value);
    final kind = switch (_field<int>(dto, 'kind')) {
      1 => WalletTransactionKind.reward,
      2 => WalletTransactionKind.hold,
      3 => WalletTransactionKind.debit,
      4 => WalletTransactionKind.release,
      5 => WalletTransactionKind.correction,
      _ => throw _invalid,
    };
    final id = _text(dto, 'transactionId');
    if (!isApiGuid(id)) throw _invalid;
    final rewardType = switch (_field<int?>(dto, 'rewardType')) {
      null => null,
      1 => WalletRewardType.welcome,
      2 => WalletRewardType.hunter,
      3 => WalletRewardType.gameCreator,
      4 => WalletRewardType.gameWinner,
      _ => throw _invalid,
    };
    if (kind == WalletTransactionKind.reward && rewardType == null) {
      throw _invalid;
    }
    return (
      id: id,
      kind: kind,
      coins: _field<int>(dto, 'coinsAmount'),
      status: _text(dto, 'status'),
      rewardType: rewardType,
      recordedAt: decodeApiUtc(_text(dto, 'recordedAtUtc')),
    );
  }

  @override
  Future<List<LiveVoucherOffer>> readOffers() async {
    final response = await _get(['vouchers', 'offers']);
    if (response is! List<Object?>) throw _invalid;
    return List.unmodifiable(response.map(_offer));
  }

  @override
  Future<LiveVoucherOffer> readOffer(String id) async {
    if (!isApiGuid(id)) throw const ApiException(ApiError.notFound);
    final offer = _offer(await _get(['vouchers', 'offers', id]));
    if (offer.id.toLowerCase() != id.toLowerCase()) throw _invalid;
    return offer;
  }

  static LiveVoucherOffer _offer(Object? value) {
    final dto = _object(value);
    final id = _text(dto, 'offerId');
    final validUntil = decodeApiUtc(_text(dto, 'validUntilUtc'));
    final stock = _field<int>(dto, 'availableStock');
    final cost = _field<int>(dto, 'costCoins');
    final referenceValue = _field<num>(dto, 'referenceValueLkr');
    if (!isApiGuid(id) ||
        stock < 0 ||
        cost < 0 ||
        !referenceValue.isFinite ||
        referenceValue < 0) {
      throw _invalid;
    }
    return (
      id: id,
      code: _text(dto, 'offerCode'),
      cost: cost,
      referenceValueLkr: referenceValue,
      validUntil: validUntil,
      availableStock: stock,
      isEligible: _field<bool>(dto, 'isEligible'),
    );
  }

  Future<Object?> _get(List<String> path, [Map<String, String>? query]) =>
      _api.request(ApiMethod.get, [..._base, ...path], query: query);

  static Map<String, Object?> _object(Object? value) {
    if (value is Map<String, Object?>) return value;
    throw _invalid;
  }

  static T _field<T>(Map<String, Object?> dto, String name) {
    final value = dto[name];
    if (dto.containsKey(name) && value is T) return value;
    throw _invalid;
  }

  static String _text(Map<String, Object?> dto, String name) {
    final value = _field<String>(dto, name);
    if (value.trim().isEmpty) throw _invalid;
    return value;
  }
}
