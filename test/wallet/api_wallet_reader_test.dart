import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/network/session_api.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/features/wallet/data/repositories/api_wallet_reader.dart';
import 'package:wayhunter_mobile/features/wallet/domain/repositories/wallet_reader.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

import '../foundation/session_and_device_test.dart' show MemoryCredentialStore;

class _Transport implements HttpTransport {
  final requests = <TransportRequest>[];
  TransportResponse response = const TransportResponse(204, []);
  bool offline = false;

  void json(Object? body, {int status = 200}) {
    response = TransportResponse(status, utf8.encode(jsonEncode(body)));
  }

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    if (offline) throw const TransportFailure();
    return response;
  }
}

Matcher _apiError(ApiError kind) =>
    isA<ApiException>().having((error) => error.kind, 'kind', kind);

void main() {
  late _Transport transport;
  late SessionController session;
  late WalletReader reader;

  setUp(() async {
    transport = _Transport();
    session = SessionController(MemoryCredentialStore());
    addTearDown(session.dispose);
    await session.authenticate(
      const SessionCredential(
        user: UserRef('test-owner'),
        accessToken: 'test-session',
      ),
    );
    reader = ApiWalletReader(
      SessionApi(
        ApiClient(
          baseUrl: Uri.parse('https://example.invalid'),
          transport: transport,
          tokens: session,
        ),
        session,
      ),
    );
  });

  test(
    'authenticated GETs decode balance, transaction page and offers',
    () async {
      transport.json({
        'postedCoins': 21000,
        'reservedCoins': 10000,
        'spendableCoins': 11000,
        'lifetimeEarnedCoins': 24000,
      });
      expect(await reader.readBalance(), (
        posted: 21000,
        reserved: 10000,
        spendable: 11000,
        lifetimeEarned: 24000,
      ));

      const id = 'e2ebc14a-019a-4093-8b67-547e72c696c8';
      transport.json({
        'page': 2,
        'pageSize': 3,
        'totalCount': 4,
        'items': [
          {
            'transactionId': id,
            'kind': 3,
            'coinsAmount': -10000,
            'status': 'Posted',
            'rewardType': null,
            'recordedAtUtc': '2026-11-26T08:00:00Z',
          },
        ],
      });
      final history = await reader.readTransactions(page: 2, pageSize: 3);
      expect((history.page, history.pageSize, history.totalCount), (2, 3, 4));
      expect(history.items.single, (
        id: id,
        kind: WalletTransactionKind.debit,
        coins: -10000,
        status: 'Posted',
        rewardType: null,
        recordedAt: DateTime.utc(2026, 11, 26, 8),
      ));

      transport.json([
        {
          'offerId': id,
          'offerCode': 'SAMPLE-LKR-100',
          'costCoins': 10000,
          'referenceValueLkr': 100.5,
          'validUntilUtc': '2027-01-01T00:00:00Z',
          'availableStock': 4,
          'isEligible': false,
        },
      ]);
      expect((await reader.readOffers()).single, (
        id: id,
        code: 'SAMPLE-LKR-100',
        cost: 10000,
        referenceValueLkr: 100.5,
        validUntil: DateTime.utc(2027),
        availableStock: 4,
        isEligible: false,
      ));

      const base = '/api/mobile/coins-wallet';
      expect(transport.requests.map((request) => request.uri.path), [
        '$base/me',
        '$base/me/transactions',
        '$base/vouchers/offers',
      ]);
      expect(transport.requests[1].uri.queryParameters, {
        'page': '2',
        'pageSize': '3',
      });
      for (final request in transport.requests) {
        expect(request.method, ApiMethod.get);
        expect(request.headers['Authorization'], 'Bearer test-session');
        expect(request.body, isNull);
      }
    },
  );

  test(
    'all three reads require credentials before calling the transport',
    () async {
      await session.clear();
      for (final read in [
        reader.readBalance,
        reader.readTransactions,
        reader.readOffers,
      ]) {
        await expectLater(read(), throwsA(_apiError(ApiError.unauthorized)));
      }
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'wallet 404 and empty collections preserve distinct empty states',
    () async {
      transport.json(null, status: 404);
      expect(await reader.readBalance(), isNull);
      await expectLater(
        reader.readOffers(),
        throwsA(_apiError(ApiError.notFound)),
      );
      transport.json({'page': 1, 'pageSize': 20, 'totalCount': 0, 'items': []});
      expect((await reader.readTransactions()).items, isEmpty);
      transport.json([]);
      expect(await reader.readOffers(), isEmpty);
    },
  );

  test('missing payloads and malformed DTOs fail safely', () async {
    for (final read in [
      reader.readBalance,
      reader.readTransactions,
      reader.readOffers,
    ]) {
      await expectLater(read(), throwsA(_apiError(ApiError.invalidResponse)));
    }
    transport.json({'postedCoins': '10'});
    await expectLater(
      reader.readBalance(),
      throwsA(_apiError(ApiError.invalidResponse)),
    );
    transport.json({
      'page': 1,
      'pageSize': 20,
      'totalCount': 1,
      'items': [null],
    });
    await expectLater(
      reader.readTransactions(),
      throwsA(_apiError(ApiError.invalidResponse)),
    );
    transport.json([
      {'offerId': 7},
    ]);
    await expectLater(
      reader.readOffers(),
      throwsA(_apiError(ApiError.invalidResponse)),
    );
  });

  test('shared HTTP and network errors propagate', () async {
    for (final entry in {
      401: ApiError.unauthorized,
      403: ApiError.forbidden,
      503: ApiError.server,
    }.entries) {
      transport.json(null, status: entry.key);
      await expectLater(reader.readBalance(), throwsA(_apiError(entry.value)));
    }
    transport.offline = true;
    await expectLater(
      reader.readTransactions(),
      throwsA(_apiError(ApiError.network)),
    );
  });

  test(
    'offer detail validates the requested identity and propagates 404',
    () async {
      const id = 'e2ebc14a-019a-4093-8b67-547e72c696c8';
      const offer = {
        'offerId': id,
        'offerCode': 'SAMPLE-LKR-100',
        'costCoins': 10000,
        'referenceValueLkr': 100,
        'validUntilUtc': '2027-01-01T00:00:00Z',
        'availableStock': 4,
        'isEligible': false,
      };
      transport.json(offer);
      expect((await reader.readOffer(id)).isEligible, isFalse);
      expect(
        transport.requests.single.uri.path,
        '/api/mobile/coins-wallet/vouchers/offers/$id',
      );
      transport.json({
        ...offer,
        'offerId': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      });
      await expectLater(
        reader.readOffer(id),
        throwsA(_apiError(ApiError.invalidResponse)),
      );
      transport.json(null, status: 404);
      await expectLater(
        reader.readOffer(id),
        throwsA(_apiError(ApiError.notFound)),
      );
    },
  );

  test(
    'reward history uses the server filter and validates kind and reward type',
    () async {
      const entry = {
        'transactionId': 'e2ebc14a-019a-4093-8b67-547e72c696c8',
        'kind': 1,
        'coinsAmount': 200,
        'status': 'Posted',
        'rewardType': 2,
        'recordedAtUtc': '2026-11-26T08:00:00Z',
      };
      const page = {'page': 1, 'pageSize': 20, 'totalCount': 1};
      transport.json({
        ...page,
        'items': [entry],
      });
      final result = await reader.readTransactions(rewardsOnly: true);
      expect(result.items.single.rewardType, WalletRewardType.hunter);
      expect(transport.requests.single.uri.queryParameters, {
        'page': '1',
        'pageSize': '20',
        'kind': 'Reward',
      });
      for (final invalid in [
        {...entry, 'kind': 2, 'rewardType': null},
        {...entry, 'rewardType': 99},
        {...entry, 'recordedAtUtc': '2026-11-31T08:00:00Z'},
      ]) {
        transport.json({
          ...page,
          'items': [invalid],
        });
        await expectLater(
          reader.readTransactions(rewardsOnly: true),
          throwsA(_apiError(ApiError.invalidResponse)),
        );
      }
    },
  );
}
