import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/features/wallet/domain/wallet_preview.dart';
import 'package:wayhunter_mobile/features/wallet/presentation/wallet_screens.dart';

Future<void> tapLabel(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
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
