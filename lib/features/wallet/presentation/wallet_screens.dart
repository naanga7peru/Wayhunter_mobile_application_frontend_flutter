import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';

import '../domain/wallet_preview.dart';

class WalletHomeScreen extends StatelessWidget {
  const WalletHomeScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) => _WalletHome(
    demo: false,
    embedded: embedded,
    readBalance: () async => null,
  );
}

/// An independent preview with no live service or mutation capability.
@visibleForTesting
Widget walletPreview(Future<WalletBalance?> Function() readBalance) {
  if (!kDebugMode) return const WalletHomeScreen();
  return _WalletHome(demo: true, readBalance: readBalance);
}

class _WalletHome extends StatefulWidget {
  const _WalletHome({
    required this.demo,
    required this.readBalance,
    this.embedded = false,
  });

  final bool demo;
  final Future<WalletBalance?> Function() readBalance;
  final bool embedded;

  @override
  State<_WalletHome> createState() => _WalletHomeState();
}

class _WalletHomeState extends State<_WalletHome> {
  late Future<WalletBalance?> _balance = widget.readBalance();

  void _retry() {
    final balance = widget.readBalance();
    setState(() {
      _balance = balance;
    });
  }

  @override
  Widget build(BuildContext context) => _WalletPage(
    title: 'Wallet',
    demo: widget.demo,
    embedded: widget.embedded,
    children: [
      FutureBuilder<WalletBalance?>(
        future: _balance,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const WayhunterLoadingView(label: 'Loading Coins balance');
          }
          if (snapshot.hasError) {
            return WayhunterErrorView(
              title: 'Could not load Coins balance',
              onRetry: _retry,
            );
          }
          final balance = snapshot.data;
          if (balance == null) {
            return widget.demo
                ? const WayhunterEmptyView(title: 'No sample balance')
                : const WayhunterUnavailableView(
                    title: 'Wallet balance unavailable',
                  );
          }
          return WayhunterSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spendable Coins',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  formatCoins(balance.spendable),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text('Reserved Coins · ${formatCoins(balance.reserved)}'),
                Text('Posted balance · ${formatCoins(balance.posted)} Coins'),
              ],
            ),
          );
        },
      ),
      _WalletLink(
        title: 'Transaction History',
        icon: Icons.receipt_long_outlined,
        onTap: () => _open(context, _History(demo: widget.demo)),
      ),
      _WalletLink(
        title: 'Voucher Offers',
        icon: Icons.local_offer_outlined,
        onTap: () =>
            _open(context, _Offers(demo: widget.demo, balance: _balance)),
      ),
      _WalletLink(
        title: 'My Vouchers',
        icon: Icons.card_giftcard_outlined,
        onTap: () => _open(context, _MyVouchers(demo: widget.demo)),
      ),
      if (!widget.demo && kDebugMode)
        WayhunterButton.secondary(
          label: 'Open Wallet DEMO',
          onPressed: () =>
              _open(context, walletPreview(() async => demoBalance)),
        ),
    ],
  );
}

class _History extends StatelessWidget {
  const _History({required this.demo});

  final bool demo;

  @override
  Widget build(BuildContext context) => _WalletPage(
    title: 'Transaction History',
    demo: demo,
    children: [
      if (!demo)
        const WayhunterUnavailableView(
          title: 'Transaction history unavailable',
        ),
      if (demo)
        for (final transaction in demoTransactions)
          _WalletLink(
            title: 'DEMO · ${transaction.title}',
            icon: transaction.coins > 0
                ? Icons.add_circle_outline
                : Icons.remove_circle_outline,
            subtitle: _TransactionAmount(transaction: transaction),
            onTap: () => _open(
              context,
              _WalletPage(
                title: 'Transaction details',
                demo: true,
                children: [
                  WayhunterHeader(
                    title: transaction.title,
                    subtitle: transaction.status,
                  ),
                  _TransactionAmount(transaction: transaction),
                ],
              ),
            ),
          ),
    ],
  );
}

class _TransactionAmount extends StatelessWidget {
  const _TransactionAmount({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final positive = transaction.coins > 0;
    return Text(
      '${positive ? '+' : '−'}${formatCoins(transaction.coins.abs())} Coins',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: positive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _Offers extends StatelessWidget {
  const _Offers({required this.demo, required this.balance});

  final bool demo;
  final Future<WalletBalance?> balance;

  @override
  Widget build(BuildContext context) => _WalletPage(
    title: 'Voucher Offers',
    demo: demo,
    children: [
      if (!demo)
        const WayhunterUnavailableView(title: 'Voucher offers unavailable'),
      if (demo)
        for (final offer in demoOffers)
          _WalletLink(
            title: offer.title,
            icon: Icons.local_offer_outlined,
            subtitle: Text('${formatCoins(offer.cost)} Coins'),
            onTap: () =>
                _open(context, _OfferDetails(offer: offer, balance: balance)),
          ),
    ],
  );
}

class _OfferDetails extends StatelessWidget {
  const _OfferDetails({required this.offer, required this.balance});

  final VoucherOffer offer;
  final Future<WalletBalance?> balance;

  @override
  Widget build(BuildContext context) => _WalletPage(
    title: 'Offer details',
    demo: true,
    children: [
      WayhunterHeader(title: offer.title),
      Text('Redemption cost · ${formatCoins(offer.cost)} Coins'),
      Text('Minimum spendable balance · ${formatCoins(offer.minimum)} Coins'),
      FutureBuilder<WalletBalance?>(
        future: balance,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const WayhunterLoadingView(
              label: 'Checking demo eligibility',
            );
          }
          final spendable = snapshot.data?.spendable;
          if (spendable == null) return const Text('Eligibility unavailable');
          if (spendable < offer.minimum) {
            return const Text('Insufficient Coins');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Eligible in this preview'),
              WayhunterButton.primary(
                label: 'Review redemption',
                onPressed: () => showWayhunterConfirmation(
                  context,
                  title: 'DEMO · Confirm redemption preview',
                  message:
                      'A real request would reserve ${formatCoins(offer.cost)} Coins while awaiting Admin review. This preview sends no request.',
                  confirmLabel: 'Close preview',
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _MyVouchers extends StatelessWidget {
  const _MyVouchers({required this.demo});

  final bool demo;

  @override
  Widget build(BuildContext context) => _WalletPage(
    title: 'My Vouchers',
    demo: demo,
    children: [
      if (!demo)
        const WayhunterUnavailableView(
          title: 'My Vouchers unavailable',
          message: 'Voucher and redemption history is unavailable.',
        ),
      if (demo)
        for (final status in RedemptionStatus.values)
          _WalletLink(
            title: status.label,
            icon: Icons.card_giftcard_outlined,
            onTap: () => _open(context, _RedemptionDetails(status: status)),
          ),
    ],
  );
}

class _RedemptionDetails extends StatefulWidget {
  const _RedemptionDetails({required this.status});

  final RedemptionStatus status;

  @override
  State<_RedemptionDetails> createState() => _RedemptionDetailsState();
}

class _RedemptionDetailsState extends State<_RedemptionDetails> {
  Future<RedemptionStatus>? _refresh;

  @override
  Widget build(BuildContext context) => _WalletPage(
    title: 'Redemption details',
    demo: true,
    children: [
      const WayhunterHeader(title: 'LKR 100 sample voucher'),
      FutureBuilder<RedemptionStatus>(
        future: _refresh,
        initialData: widget.status,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const WayhunterLoadingView(label: 'Refreshing demo status');
          }
          final status = snapshot.data!;
          if (status == RedemptionStatus.issuanceError) {
            return WayhunterErrorView(
              title: status.label,
              message: status.description,
              onRetry: () {
                final refresh = Future(() => widget.status);
                setState(() {
                  _refresh = refresh;
                });
              },
            );
          }
          return WayhunterSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(status.description),
                if (status == RedemptionStatus.issued) ...[
                  const SizedBox(height: WayhunterLayout.medium),
                  const ListTile(
                    leading: Icon(Icons.image_outlined),
                    title: Text('Voucher image preview'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.password_outlined),
                    title: Text('Voucher code withheld in preview'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.qr_code),
                    title: Text('QR preview placeholder'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ],
  );
}

void _open(BuildContext context, Widget page) {
  Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
}

class _WalletPage extends StatelessWidget {
  const _WalletPage({
    required this.title,
    required this.demo,
    required this.children,
    this.embedded = false,
  });

  final String title;
  final bool demo;
  final List<Widget> children;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(WayhunterLayout.pagePadding),
      children: [
        if (embedded) WayhunterHeader(title: title),
        if (demo) const Text('DEMO · Sample data'),
        for (final child in children)
          Padding(
            padding: const EdgeInsets.only(bottom: WayhunterLayout.medium),
            child: child,
          ),
      ],
    );
    if (embedded) return body;
    return WayhunterPageScaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

class _WalletLink extends StatelessWidget {
  const _WalletLink({
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
