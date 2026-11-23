typedef WalletBalance = ({int spendable, int reserved, int posted});

typedef WalletTransaction = ({String title, int coins, String status});

typedef VoucherOffer = ({String title, int cost, int minimum});

enum RedemptionStatus {
  pending(
    'Pending',
    'The sample request reserves Coins while awaiting review.',
  ),
  approved(
    'Approved, awaiting issuance',
    'The debit is posted. Issuance is a separate step.',
  ),
  rejected('Rejected', 'The reservation was released.'),
  cancelled(
    'Cancelled',
    'The reservation was released after permitted cancellation.',
  ),
  issued('Issued', 'The voucher is available after issuance.'),
  issuanceError(
    'Issuance error',
    'The approved debit remains posted while issuance is retried by Admin.',
  );

  const RedemptionStatus(this.label, this.description);

  final String label;
  final String description;
}

const demoBalance = (spendable: 10500, reserved: 10000, posted: 20500);

const List<WalletTransaction> demoTransactions = [
  (title: 'Hunter approval', coins: 200, status: 'Posted reward'),
  (title: 'Game creation approval', coins: 100, status: 'Posted reward'),
  (title: 'Verified Game winner', coins: 100, status: 'Posted reward'),
  (title: 'Voucher redemption', coins: -10000, status: 'Posted debit'),
];

const List<VoucherOffer> demoOffers = [
  (title: 'LKR 100 sample voucher', cost: 10000, minimum: 10100),
];

String formatCoins(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);
