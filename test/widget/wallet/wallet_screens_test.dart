import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/router/app_router.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/features/wallet/domain/repositories/wallet_reader.dart';
import 'package:wayhunter_mobile/features/wallet/domain/repositories/voucher_redemption_repository.dart';
import 'package:wayhunter_mobile/features/wallet/domain/voucher_redemption.dart';
import 'package:wayhunter_mobile/features/wallet/domain/wallet_preview.dart';
import 'package:wayhunter_mobile/features/wallet/presentation/wallet_screens.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

import '../../foundation/api_client_test.dart' show FakeTransport;
import '../../foundation/session_and_device_test.dart'
    show MemoryCredentialStore;

Future<void> tapLabel(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

class _Reader implements WalletReader {
  Future<LiveWalletBalance?> Function() balance = () async =>
      (posted: 310, reserved: 10, spendable: 300, lifetimeEarned: 510);
  Future<WalletTransactionPage> Function(int, int) transactions =
      (page, size) async => (
        page: page,
        pageSize: size,
        totalCount: 0,
        items: <LiveWalletTransaction>[],
      );
  Future<List<LiveVoucherOffer>> Function() offers = () async => [];
  final pages = <int>[];

  @override
  Future<LiveWalletBalance?> readBalance() => balance();

  @override
  Future<WalletTransactionPage> readTransactions({
    int page = 1,
    int pageSize = 20,
  }) {
    pages.add(page);
    return transactions(page, pageSize);
  }

  @override
  Future<List<LiveVoucherOffer>> readOffers() => offers();
}

void main() {
  testWidgets('voucher lookup reveals QR only after issued status', (
    tester,
  ) async {
    final repository = _RedemptionRepository()..approved = true;
    await tester.pumpWidget(
      MaterialApp(
        home: WalletHomeScreen(reader: _Reader(), redemption: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Find voucher request');
    await tester.enterText(find.byType(TextFormField), 'test-request');
    await tapLabel(tester, 'Find request');
    expect(find.text('Approved'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await tapLabel(tester, 'Check voucher issuance');
    expect(find.text('Awaiting issuance'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    repository.issued = true;
    await tapLabel(tester, 'Check voucher issuance');
    expect(find.text('Voucher issued'), findsOneWidget);
    expect(find.text('Voucher code: TEST-ONLY'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });
  testWidgets(
    'live redemption checks balance and reconciles an uncertain create',
    (tester) async {
      var spendable = 10099;
      final reader = _Reader();
      reader.balance = () async => (
        posted: spendable,
        reserved: 0,
        spendable: spendable,
        lifetimeEarned: spendable,
      );
      reader.offers = () async => [
        (
          id: 'test-offer',
          code: 'TEST-OFFER',
          cost: 10000,
          referenceValueLkr: 100,
          validUntil: DateTime.now().add(const Duration(days: 1)),
          availableStock: 1,
          isEligible: true,
        ),
      ];
      final repository = _RedemptionRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: WalletHomeScreen(reader: reader, redemption: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Voucher Offers');
      await tapLabel(tester, 'TEST-OFFER');
      await tapLabel(tester, 'Review redemption');
      expect(
        find.text('At least 10,100 spendable Coins are required.'),
        findsOneWidget,
      );
      expect(repository.creates, 0);

      spendable = 10100;
      await tapLabel(tester, 'Review redemption');
      await tapLabel(tester, 'Request voucher');
      expect(repository.creates, 1);
      expect(find.text('Pending Admin review'), findsNothing);
      await tapLabel(tester, 'Check request and retry');
      expect(repository.creates, 1);
      expect(find.text('Pending Admin review'), findsOneWidget);
      expect(find.text('Check voucher issuance'), findsNothing);

      await tester.ensureVisible(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'Entered in error');
      await tapLabel(tester, 'Review cancellation');
      await tapLabel(tester, 'Cancel request');
      expect(repository.cancelReason, 'Entered in error');
      expect(find.text('Cancelled'), findsOneWidget);
    },
  );
  testWidgets('Wallet route uses the shared session and clears data on sign-out', (
    tester,
  ) async {
    final session = SessionController(MemoryCredentialStore());
    addTearDown(session.dispose);
    final transport = FakeTransport((request) async {
      final body = request.uri.path.endsWith('/transactions')
          ? '{"page":1,"pageSize":20,"totalCount":1,"items":[{"transactionId":"test","kind":1,"coinsAmount":777,"status":"Posted"}]}'
          : '{"postedCoins":300,"reservedCoins":0,"spendableCoins":300,"lifetimeEarnedCoins":500}';
      return TransportResponse(200, utf8.encode(body));
    });
    final router = AppRouter((_) {});
    await tester.pumpWidget(
      FoundationServices(
        session: session,
        api: ApiClient(
          baseUrl: Uri.parse('https://example.invalid'),
          transport: transport,
          tokens: session,
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  router.destination(context, AppRoutes.wallet),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wallet balance unavailable'), findsOneWidget);
    expect(transport.requests, isEmpty);
    await session.authenticate(
      const SessionCredential(
        user: UserRef('test-user'),
        accessToken: 'route-test-token',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('300'), findsOneWidget);
    await tapLabel(tester, 'Transaction History');
    expect(find.text('+777 Coins'), findsOneWidget);
    expect(
      transport.requests.map((request) => request.headers['Authorization']),
      ['Bearer route-test-token', 'Bearer route-test-token'],
    );
    await session.clear();
    await tester.pumpAndSettle();
    expect(find.text('Wallet session changed'), findsOneWidget);
    expect(find.text('+777 Coins'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Wallet balance unavailable'), findsOneWidget);
    expect(find.text('300'), findsNothing);
  });

  testWidgets('live balance loads, retries and isolates the debug demo', (
    tester,
  ) async {
    final first = Completer<LiveWalletBalance?>();
    final reader = _Reader();
    final successfulBalance = reader.balance;
    reader.balance = () => first.future;
    await tester.pumpWidget(
      MaterialApp(home: WalletHomeScreen(reader: reader)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    first.completeError(const ApiException(ApiError.server));
    await tester.pumpAndSettle();
    expect(find.text('Could not load Coins balance'), findsOneWidget);
    reader.balance = successfulBalance;
    await tapLabel(tester, 'Retry');
    expect(find.text('300'), findsOneWidget);
    expect(find.text('Reserved Coins · 10'), findsOneWidget);
    expect(find.text('Posted balance · 310 Coins'), findsOneWidget);
    expect(find.text('Lifetime-earned Coins · 510'), findsOneWidget);
    expect(find.text('10,500'), findsNothing);
    await tapLabel(tester, 'Open Wallet DEMO');
    expect(find.text('DEMO · Sample data'), findsOneWidget);
    expect(find.text('10,500'), findsOneWidget);
    expect(find.text('Lifetime-earned Coins · 510'), findsNothing);
    await tapLabel(tester, 'Transaction History');
    expect(reader.pages, isEmpty);
  });

  testWidgets('live wallet shows empty balance, history and offers', (
    tester,
  ) async {
    final reader = _Reader();
    reader.balance = () async => null;
    await tester.pumpWidget(
      MaterialApp(home: WalletHomeScreen(reader: reader)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No Coins wallet found'), findsOneWidget);
    await tapLabel(tester, 'Transaction History');
    expect(find.text('No transactions on this page'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Voucher Offers');
    expect(find.text('No voucher offers'), findsOneWidget);
  });

  testWidgets('history retries the same page and navigates both directions', (
    tester,
  ) async {
    final reader = _Reader();
    var failSecondPage = true;
    reader.transactions = (page, size) async {
      if (page == 2 && failSecondPage) {
        failSecondPage = false;
        throw const ApiException(ApiError.network);
      }
      return (
        page: page,
        pageSize: size,
        totalCount: size + 1,
        items: [
          (
            id: 'row-$page',
            kind: page == 1
                ? WalletTransactionKind.reward
                : WalletTransactionKind.hold,
            coins: page == 1 ? 100 : -10000,
            status: page == 1 ? 'Posted' : 'Pending',
          ),
        ],
      );
    };
    await tester.pumpWidget(
      MaterialApp(home: WalletHomeScreen(reader: reader)),
    );
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Transaction History');
    expect(find.text('Reward'), findsOneWidget);
    expect(find.text('+100 Coins'), findsOneWidget);
    expect(find.text('Posted'), findsOneWidget);
    await tapLabel(tester, 'Next page');
    expect(find.text('Could not load transaction history'), findsOneWidget);
    await tapLabel(tester, 'Retry');
    expect(find.text('Page 2'), findsOneWidget);
    expect(find.text('−10,000 Coins'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Next page'))
          .onPressed,
      isNull,
    );
    await tapLabel(tester, 'Previous page');
    expect(reader.pages, [1, 2, 2, 1]);
  });

  testWidgets('live offers show backend details with redemption unavailable', (
    tester,
  ) async {
    final reader = _Reader();
    final result = Completer<List<LiveVoucherOffer>>();
    reader.offers = () => result.future;
    await tester.pumpWidget(
      MaterialApp(home: WalletHomeScreen(reader: reader)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voucher Offers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    result.complete([
      (
        id: 'offer-id',
        code: 'SAMPLE-OFFER',
        cost: 8000,
        referenceValueLkr: 50,
        validUntil: DateTime.utc(2027),
        availableStock: 2,
        isEligible: false,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('8,000 Coins'), findsOneWidget);
    expect(find.text('Available stock · 2'), findsOneWidget);
    expect(find.text('Not eligible'), findsOneWidget);
    await tapLabel(tester, 'SAMPLE-OFFER');
    expect(find.text('Reference value · LKR 50.00'), findsOneWidget);
    expect(find.text('Voucher redemption unavailable'), findsOneWidget);
    expect(find.text('Review redemption'), findsNothing);
    expect(find.text('DEMO · Sample data'), findsNothing);
  });

  testWidgets('balance loads, retries after failure, and shows empty state', (
    tester,
  ) async {
    final firstRead = Completer<WalletBalance?>();
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: walletPreview(
          () => reads++ == 0 ? firstRead.future : Future.value(null),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    firstRead.completeError(StateError('fixture read failed'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load Coins balance'), findsOneWidget);
    await tapLabel(tester, 'Retry');
    expect(reads, 2);
    expect(find.text('No sample balance'), findsOneWidget);
  });

  testWidgets(
    'demo wallet shows distinct balances and signed transaction details',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WalletHomeScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Wallet balance unavailable'), findsOneWidget);
      await tapLabel(tester, 'Open Wallet DEMO');
      expect(find.text('DEMO · Sample data'), findsOneWidget);
      expect(find.text('10,500'), findsOneWidget);
      expect(find.text('Reserved Coins · 10,000'), findsOneWidget);
      expect(find.text('Posted balance · 20,500 Coins'), findsOneWidget);
      await tapLabel(tester, 'Transaction History');
      expect(find.text('+200 Coins'), findsOneWidget);
      await tapLabel(tester, 'DEMO · Voucher redemption');
      expect(find.text('−10,000 Coins'), findsOneWidget);
      expect(find.text('Posted debit'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Transaction History'), findsOneWidget);
    },
  );

  for (final spendable in [10099, 10100]) {
    testWidgets('sample offer checks eligibility at $spendable Coins', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: walletPreview(
            () async => (spendable: spendable, reserved: 0, posted: spendable),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Voucher Offers');
      await tapLabel(tester, 'LKR 100 sample voucher');
      if (spendable < 10100) {
        expect(find.text('Insufficient Coins'), findsOneWidget);
        expect(find.text('Review redemption'), findsNothing);
      } else {
        await tapLabel(tester, 'Review redemption');
        expect(find.text('DEMO · Confirm redemption preview'), findsOneWidget);
        await tapLabel(tester, 'Close preview');
        expect(find.text('Eligible in this preview'), findsOneWidget);
      }
    });
  }

  testWidgets(
    'voucher status previews gate the issued shell and retry keeps the demo error',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: walletPreview(() async => demoBalance)),
      );
      await tester.pumpAndSettle();
      await tapLabel(tester, 'My Vouchers');
      for (final status in RedemptionStatus.values) {
        await tapLabel(tester, status.label);
        expect(find.text('DEMO · Sample data'), findsOneWidget);
        expect(find.text(status.description), findsOneWidget);
        expect(
          find.text('QR preview placeholder'),
          status == RedemptionStatus.issued ? findsOneWidget : findsNothing,
        );
        if (status == RedemptionStatus.issuanceError) {
          await tapLabel(tester, 'Retry');
          expect(find.text(status.description), findsOneWidget);
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    },
  );
}

class _RedemptionRepository implements VoucherRedemptionRepository {
  int creates = 0;
  bool approved = false;
  bool issued = false;
  String? cancelReason;

  @override
  VoucherRedemptionIntent prepareCreate(String offerId) => _Intent(offerId);

  @override
  Future<VoucherRedemptionRequest> create(
    VoucherRedemptionIntent intent,
  ) async {
    creates++;
    throw const ApiException(ApiError.timeout);
  }

  @override
  Future<VoucherRedemptionRequest> readRequest(String requestId) async => (
    requestId: requestId,
    offerId: 'test-offer',
    ownerUserId: 'test-user',
    ownerName: 'Test User',
    costCoins: 10000,
    status: approved
        ? VoucherRequestStatus.approved
        : cancelReason == null
        ? VoucherRequestStatus.pending
        : VoucherRequestStatus.cancelled,
    requestedAtUtc: DateTime.utc(2026),
    decidedAtUtc: null,
    decisionReason: cancelReason,
  );

  @override
  Future<VoucherRedemptionRequest> cancel(String requestId, String reason) {
    cancelReason = reason;
    return readRequest(requestId);
  }

  @override
  Future<IssuedVoucher> readIssuedVoucher(String requestId) async =>
      _TestVoucher(requestId, issued);
}

class _Intent implements VoucherRedemptionIntent {
  const _Intent(this.offerId);

  @override
  final String offerId;

  @override
  String get requestId => 'test-request';
}

class _TestVoucher implements IssuedVoucher {
  const _TestVoucher(this.requestId, this.issued);

  @override
  final String requestId;
  final bool issued;

  @override
  VoucherIssuanceStatus get status =>
      issued ? VoucherIssuanceStatus.issued : VoucherIssuanceStatus.unissued;

  @override
  num get referenceValueLkr => 100;

  @override
  DateTime? get expiresAtUtc => null;

  @override
  DateTime? get issuedAtUtc => null;

  @override
  DateTime? get usedAtUtc => null;

  @override
  String? get voucherCode => issued ? 'TEST-ONLY' : null;

  @override
  String? get qrPayload => issued ? 'synthetic-test-payload' : null;
}
