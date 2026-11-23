import 'dart:convert';

import 'package:wayhunter_mobile/core/network/api_client.dart';

const walletBalancePath = '/api/mobile/coins-wallet/me';
const fixtureSpendableCoins = 625;

TransportResponse walletBalanceResponse() => TransportResponse(
  200,
  utf8.encode(
    jsonEncode({
      'postedCoins': fixtureSpendableCoins,
      'reservedCoins': 0,
      'spendableCoins': fixtureSpendableCoins,
      'lifetimeEarnedCoins': 800,
    }),
  ),
);
