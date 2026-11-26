typedef LiveWalletBalance = ({
  int posted,
  int reserved,
  int spendable,
  int lifetimeEarned,
});

enum WalletTransactionKind { reward, hold, debit, release, correction }

enum WalletRewardType {
  welcome('Welcome reward'),
  hunter('Hunter approval reward'),
  gameCreator('Game creation reward'),
  gameWinner('Game winner reward');

  const WalletRewardType(this.label);
  final String label;
}

typedef LiveWalletTransaction = ({
  String id,
  WalletTransactionKind kind,
  int coins,
  String status,
  WalletRewardType? rewardType,
  DateTime recordedAt,
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
    bool rewardsOnly = false,
  });
  Future<List<LiveVoucherOffer>> readOffers();
  Future<LiveVoucherOffer> readOffer(String id);
}
