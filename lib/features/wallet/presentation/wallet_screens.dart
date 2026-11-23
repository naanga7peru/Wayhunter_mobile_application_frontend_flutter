import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';

import '../domain/repositories/wallet_reader.dart';
import '../domain/wallet_preview.dart';

class WalletHomeScreen extends StatelessWidget {
  const WalletHomeScreen({super.key, this.embedded = false, this.reader});

  final WalletReader? reader;

  final bool embedded;

  @override
  Widget build(BuildContext context) => _WalletHome(
    demo: false,
    reader: reader,
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
    this.reader,
    this.embedded = false,
  });

  final bool demo;
  final Future<WalletBalance?> Function() readBalance;
  final WalletReader? reader;
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
      if (widget.reader case final reader?)
        _WalletRead<LiveWalletBalance?>(
          key: ObjectKey(reader),
          label: 'Coins balance',
          read: reader.readBalance,
          content: (balance) => balance == null
              ? const WayhunterEmptyView(title: 'No Coins wallet found')
              : _BalanceCard(
                  spendable: balance.spendable,
                  reserved: balance.reserved,
                  posted: balance.posted,
                  lifetimeEarned: balance.lifetimeEarned,
                ),
        )
      else
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
            return _BalanceCard(
              spendable: balance.spendable,
              reserved: balance.reserved,
              posted: balance.posted,
            );
          },
        ),
      _WalletLink(
        title: 'Transaction History',
        icon: Icons.receipt_long_outlined,
        onTap: () => _open(
          context,
          widget.reader != null
              ? _LiveHistory(reader: widget.reader!)
              : _History(demo: widget.demo),
        ),
      ),
      _WalletLink(
        title: 'Voucher Offers',
        icon: Icons.local_offer_outlined,
        onTap: () => _open(
          context,
          widget.reader != null
              ? _LiveOffers(reader: widget.reader!)
              : _Offers(demo: widget.demo, balance: _balance),
        ),
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

class _WalletRead<T> extends StatefulWidget {
  const _WalletRead({
    super.key,
    required this.label,
    required this.read,
    required this.content,
  });

  final String label;
  final Future<T> Function() read;
  final Widget Function(T) content;

  @override
  State<_WalletRead<T>> createState() => _WalletReadState<T>();
}

class _WalletReadState<T> extends State<_WalletRead<T>> {
  late Future<T> _result = widget.read();

  void _retry() {
    final result = widget.read();
    setState(() {
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _result,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return WayhunterLoadingView(label: 'Loading ${widget.label}');
      }
      if (snapshot.hasError) {
        final error = snapshot.error;
        final message = switch (error) {
          ApiException(kind: ApiError.unauthorized) =>
            'An authenticated mobile session is required.',
          ApiException(kind: ApiError.forbidden) => 'The server denied access.',
          _ => null,
        };
        if (error is ApiException && error.kind == ApiError.unavailable) {
          return WayhunterUnavailableView(
            title: '${widget.label} unavailable',
            action: WayhunterButton.secondary(
              label: 'Retry',
              onPressed: _retry,
            ),
          );
        }
        return WayhunterErrorView(
          title: 'Could not load ${widget.label}',
          message: message,
          onRetry: _retry,
        );
      }
      return widget.content(snapshot.data as T);
    },
  );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.spendable,
    required this.reserved,
    required this.posted,
    this.lifetimeEarned,
  });

  final int spendable;
  final int reserved;
  final int posted;
  final int? lifetimeEarned;

  @override
  Widget build(BuildContext context) => WayhunterSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Spendable Coins', style: Theme.of(context).textTheme.titleMedium),
        Text(
          formatCoins(spendable),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text('Reserved Coins · ${formatCoins(reserved)}'),
        Text('Posted balance · ${formatCoins(posted)} Coins'),
        if (lifetimeEarned case final earned?)
          Text('Lifetime-earned Coins · ${formatCoins(earned)}'),
      ],
    ),
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
            subtitle: _TransactionAmount(coins: transaction.coins),
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
                  _TransactionAmount(coins: transaction.coins),
                ],
              ),
            ),
          ),
    ],
  );
}

class _LiveHistory extends StatefulWidget {
  const _LiveHistory({required this.reader});

  final WalletReader reader;

  @override
  State<_LiveHistory> createState() => _LiveHistoryState();
}

class _LiveHistoryState extends State<_LiveHistory> {
  int _page = 1;
  int _pageSize = 20;

  void _goTo(int page, int pageSize) => setState(() {
    _page = page;
    _pageSize = pageSize;
  });

  @override
  Widget build(BuildContext context) => _WalletPage(
    title: 'Transaction History',
    demo: false,
    children: [
      _WalletRead<WalletTransactionPage>(
        key: ValueKey(_page),
        label: 'transaction history',
        read: () =>
            widget.reader.readTransactions(page: _page, pageSize: _pageSize),
        content: (result) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result.items.isEmpty)
              const WayhunterEmptyView(title: 'No transactions on this page'),
            for (final entry in result.items) _liveTransaction(entry),
            Text('Page ${result.page}'),
            Wrap(
              spacing: WayhunterLayout.medium,
              children: [
                TextButton(
                  onPressed: result.page > 1
                      ? () => _goTo(result.page - 1, result.pageSize)
                      : null,
                  child: const Text('Previous page'),
                ),
                TextButton(
                  onPressed: result.page * result.pageSize < result.totalCount
                      ? () => _goTo(result.page + 1, result.pageSize)
                      : null,
                  child: const Text('Next page'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _liveTransaction(LiveWalletTransaction entry) {
    final kind = switch (entry.kind) {
      WalletTransactionKind.reward => 'Reward',
      WalletTransactionKind.hold => 'Hold',
      WalletTransactionKind.debit => 'Debit',
      WalletTransactionKind.release => 'Release',
      WalletTransactionKind.correction => 'Correction',
    };
    return _WalletLink(
      key: ValueKey((entry.id, entry.kind)),
      title: kind,
      icon: Icons.receipt_long_outlined,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TransactionAmount(coins: entry.coins),
          Text(entry.status),
        ],
      ),
      onTap: () => _open(
        context,
        _WalletPage(
          title: 'Transaction details',
          demo: false,
          children: [
            WayhunterHeader(title: kind, subtitle: entry.status),
            _TransactionAmount(coins: entry.coins),
          ],
        ),
      ),
    );
  }
}

class _TransactionAmount extends StatelessWidget {
  const _TransactionAmount({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final positive = coins > 0;
    return Text(
      '${positive
          ? '+'
          : coins < 0
          ? '−'
          : ''}${formatCoins(coins.abs())} Coins',
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

class _LiveOffers extends StatelessWidget {
  const _LiveOffers({required this.reader});

  final WalletReader reader;

  @override
  Widget build(BuildContext context) => _WalletPage(
    title: 'Voucher Offers',
    demo: false,
    children: [
      _WalletRead<List<LiveVoucherOffer>>(
        label: 'voucher offers',
        read: reader.readOffers,
        content: (offers) => offers.isEmpty
            ? const WayhunterEmptyView(title: 'No voucher offers')
            : Column(
                children: [
                  for (final offer in offers)
                    _WalletLink(
                      key: ValueKey(offer.id),
                      title: offer.code,
                      icon: Icons.local_offer_outlined,
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${formatCoins(offer.cost)} Coins'),
                          Text(_offerStock(offer)),
                          Text(_offerEligibility(offer)),
                        ],
                      ),
                      onTap: () => _open(
                        context,
                        _WalletPage(
                          title: 'Offer details',
                          demo: false,
                          children: [
                            WayhunterHeader(title: offer.code),
                            Text(
                              'Redemption cost · ${formatCoins(offer.cost)} Coins',
                            ),
                            Text(
                              'Reference value · LKR ${offer.referenceValueLkr.toStringAsFixed(2)}',
                            ),
                            Text(
                              'Valid until · ${MaterialLocalizations.of(context).formatMediumDate(offer.validUntil.toLocal())} '
                              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(offer.validUntil.toLocal()))}',
                            ),
                            Text(_offerStock(offer)),
                            Text(_offerEligibility(offer)),
                            const Text('Voucher redemption unavailable'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ],
  );

  String _offerStock(LiveVoucherOffer offer) => offer.availableStock == 0
      ? 'Out of stock'
      : 'Available stock · ${offer.availableStock}';

  String _offerEligibility(LiveVoucherOffer offer) =>
      offer.isEligible ? 'Eligible' : 'Not eligible';
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
  final session = context
      .getInheritedWidgetOfExactType<FoundationServices>()
      ?.session;
  final openingState = session?.state;
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => session == null
          ? page
          : ListenableBuilder(
              listenable: session,
              builder: (context, _) => identical(session.state, openingState)
                  ? page
                  : const _WalletPage(
                      title: 'Wallet',
                      demo: false,
                      children: [
                        WayhunterUnavailableView(
                          title: 'Wallet session changed',
                        ),
                      ],
                    ),
            ),
    ),
  );
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
    super.key,
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
