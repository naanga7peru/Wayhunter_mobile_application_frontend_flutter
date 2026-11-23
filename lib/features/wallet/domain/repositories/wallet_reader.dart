typedef LiveWalletBalance = ({
  int posted,
  int reserved,
  int spendable,
  int lifetimeEarned,
});

enum WalletTransactionKind { reward, hold, debit, release, correction }

typedef LiveWalletTransaction = ({
  String id,
  WalletTransactionKind kind,
  int coins,
  String status,
});

typedef WalletTransactionPage = ({
  int page,
  int pageSize,
  int totalCount,
  List<LiveWalletTransaction> items,
});

typedef LiveVoucherOffer = ({
  String id,
  String code,
  int cost,
  num referenceValueLkr,
  DateTime validUntil,
  int availableStock,
  bool isEligible,
});

abstract interface class WalletReader {
  /// Null means the wallet controller found no wallet for the user.
  Future<LiveWalletBalance?> readBalance();
  Future<WalletTransactionPage> readTransactions({
    int page = 1,
    int pageSize = 20,
  });
  Future<List<LiveVoucherOffer>> readOffers();
}
