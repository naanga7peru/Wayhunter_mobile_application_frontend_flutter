import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/advertisements/data/home_advertisements_api.dart';
import 'package:wayhunter_mobile/features/advertisements/presentation/home_banner.dart';
import 'package:wayhunter_mobile/features/profile/data/my_profile_api.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

import 'wallet_balance_fixture.dart';

const _owner = '20000000-0000-0000-0000-000000000001';
const _other = '20000000-0000-0000-0000-000000000002';
const _ads = '/api/mobile/advertisements/active';
const _me = '/api/mobile/identity/me';
TransportResponse _json(Object? value) =>
    TransportResponse(200, utf8.encode(jsonEncode(value)));

Map<String, Object?> _profile(bool other) => {
  'userId': other ? _other : _owner,
  'displayName': other ? 'Second visitor' : 'First visitor',
  'email': other ? 'second@example.invalid' : 'first@example.invalid',
  'avatarUrl': 'http://invalid.example/avatar.png',
  'bio': other ? null : 'Synthetic bio',
  'phoneNumber': other ? null : '+0001234',
  'adminNote': 'Never render this extra field',
};

Map<String, Object?> _ad({
  String title = 'Synthetic Home banner',
  String image = 'https://images.example.invalid/banner.png',
  String destination = 'https://www.example.invalid/offer',
  bool enabled = true,
  int placement = 1,
  int status = 1,
}) => {
  'id': '20000000-0000-0000-0000-000000000003',
  'title': title,
  'imageUrl': image,
  'destinationUrl': destination,
  'startAtUtc': '2026-11-01T00:00:00+00:00',
  'endAtUtc': '2026-12-01T00:00:00+00:00',
  'isEnabled': enabled,
  'placement': placement,
  'status': status,
};

class _Store implements CredentialStore {
  SessionCredential? value;
  @override
  Future<SessionCredential?> read() async => value;
  @override
  Future<void> write(SessionCredential credential) async => value = credential;
  @override
  Future<void> clear() async => value = null;
}

class _Transport implements HttpTransport {
  final requests = <TransportRequest>[];
  late FutureOr<TransportResponse> Function(TransportRequest) respond;
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return respond(request);
  }
}

class _Harness {
  final store = _Store();
  final transport = _Transport();
  Iterable<TransportRequest> get adRequests =>
      transport.requests.where((request) => request.uri.path == _ads);
  late final session = SessionController(store);
  late final api = ApiClient(
    baseUrl: Uri.https('example.invalid'),
    transport: transport,
    tokens: session,
  );
  static const credential = SessionCredential(
    user: UserRef(_owner),
    accessToken: 'synthetic-owner',
  );

  Future<void> open(
    WidgetTester tester, {
    Size viewport = const Size(800, 1000),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = viewport;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    store.value = credential;
    await tester.pumpWidget(
      FoundationServices(
        api: api,
        session: session,
        child: const WayhunterApp.authenticated(apiConfigured: true),
      ),
    );
    await _finishTransition(tester);
  }

  void mock({
    FutureOr<TransportResponse> Function()? profile,
    FutureOr<TransportResponse> Function(TransportRequest)? updateProfile,
    FutureOr<TransportResponse> Function(bool other)? ads,
  }) {
    transport.respond = (request) {
      final other =
          request.headers['Authorization'] == 'Bearer synthetic-other';
      return switch (request.uri.path) {
        _me when request.method == ApiMethod.put && updateProfile != null =>
          updateProfile(request),
        _me => profile?.call() ?? _json(_profile(other)),
        _ads => ads?.call(other) ?? _json([]),
        '/api/mobile/hunter/places' ||
        '/api/mobile/hunter/submissions' ||
        '/api/mobile/games/me' => _json([]),
        walletBalancePath => walletBalanceResponse(),
        '/api/mobile/notifications' => _json({'items': [], 'unreadCount': 0}),
        '/api/mobile/auth/logout' => const TransportResponse(204, []),
        '/api/mobile/identity/login' => _json({
          'userId': _other,
          'accessToken': 'synthetic-other',
          'expiresAtUtc': '2099-01-01T00:00:00Z',
        }),
        _ => fail('Unexpected request'),
      };
    };
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await _finishTransition(tester);
}

Future<void> _finishTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

Future<void> _advanceRefresh(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 15));
  await tester.pump();
}

void main() {
  const avatarUrl = 'https://images.example.invalid/home-avatar.png';

  testWidgets('Home displays the authenticated avatar beside the greeting', (
    tester,
  ) async {
    const provider = NetworkImage(avatarUrl);
    final image = await tester.runAsync(() => createTestImage(cache: false));
    final cache = PaintingBinding.instance.imageCache;
    cache.putIfAbsent(
      provider,
      () =>
          OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image!))),
    );
    addTearDown(() => cache.evict(provider));
    final h = _Harness()
      ..mock(
        profile: () => _json({..._profile(false), 'avatarUrl': avatarUrl}),
      );
    await h.open(tester);

    final avatar = find.byWidgetPredicate(
      (widget) => widget is Image && widget.image == provider,
    );
    expect(find.text('Hello, First visitor'), findsOneWidget);
    expect(find.text('first@example.invalid'), findsNothing);
    expect(avatar, findsOneWidget);
    expect(
      find.descendant(
        of: avatar,
        matching: find.byWidgetPredicate(
          (widget) => widget is RawImage && widget.image != null,
        ),
      ),
      findsOneWidget,
    );
  });

  for (final (label, url) in [
    ('missing URL', null),
    ('invalid URL', 'http://invalid.example/avatar.png'),
    ('image request failure', avatarUrl),
  ]) {
    testWidgets('Home preserves greeting with avatar fallback on $label', (
      tester,
    ) async {
      final h = _Harness()
        ..mock(profile: () => _json({..._profile(false), 'avatarUrl': url}));
      await h.open(tester);

      expect(find.text('Hello, First visitor'), findsOneWidget);
      expect(
        find.widgetWithIcon(CircleAvatar, Icons.person_outline),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final (viewport, width) in [
    (const Size(320, 640), 280.0),
    (const Size(1280, 800), 560.0),
  ]) {
    testWidgets('Home avatar and module navigation at ${viewport.width} px', (
      tester,
    ) async {
      final h = _Harness()..mock();
      await h.open(tester, viewport: viewport);

      expect(
        tester.getSize(find.byType(WayhunterSurfaceCard).first).width,
        width,
      );
      expect(find.text('Hello, First visitor'), findsOneWidget);
      expect(
        find.widgetWithIcon(CircleAvatar, Icons.person_outline),
        findsOneWidget,
      );
      for (final label in ['Traveler', 'Location Hunter', 'Game']) {
        await _tap(tester, label);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1,
        );
        await _tap(tester, 'Home');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Home greeting, scenic image, module entries and notifications inbox',
    (tester) async {
      final h = _Harness()..mock();
      await h.open(tester);
      expect(find.text('Hello, First visitor'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('No active advertisements'), findsOneWidget);
      for (final label in ['Traveler', 'Location Hunter', 'Game']) {
        await _tap(tester, label);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1,
        );
        await _tap(tester, 'Home');
      }
      await _tap(tester, 'Notifications');
      expect(find.text('No notifications'), findsOneWidget);
    },
  );

  for (final (scenario, adsResponse, fallback)
      in <(String, TransportResponse, String)>[
        ('empty advertisement response', _json([]), 'No active advertisements'),
        (
          'advertisement request failure',
          const TransportResponse(503, []),
          'Could not load advertisements',
        ),
      ]) {
    testWidgets('Home remains usable with $scenario', (tester) async {
      final h = _Harness()..mock(ads: (_) => adsResponse);
      await h.open(tester);

      expect(find.text('Hello, First visitor'), findsOneWidget);
      expect(find.text(fallback), findsOneWidget);
      for (final label in ['Traveler', 'Location Hunter', 'Game']) {
        await _tap(tester, label);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1,
        );
        await _tap(tester, 'Home');
        expect(find.text('Hello, First visitor'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      expect(tester.takeException(), isNull);
      h.session.dispose();
    });
  }

  testWidgets(
    'My Profile shows owner fields and preserves Person 2 shortcuts',
    (tester) async {
      final h = _Harness()..mock();
      await h.open(tester);
      await _tap(tester, 'My profile');
      for (final value in [
        'First visitor',
        'first@example.invalid',
        'Synthetic bio',
        '+0001234',
      ]) {
        expect(find.text(value), findsOneWidget);
      }
      expect(find.text('Never render this extra field'), findsNothing);
      expect(find.byType(Image), findsNothing);
      for (final (label, state) in [
        ('Wallet', '$fixtureSpendableCoins'),
        ('My Hunts', 'No hunts yet'),
        ('My Games', 'No games yet'),
      ]) {
        await _tap(tester, label);
        expect(find.text(state), findsOneWidget);
        await tester.pageBack();
        await _finishTransition(tester);
      }
      await _tap(tester, 'Edit Profile');
      expect(find.text('Save profile'), findsOneWidget);
    },
  );

  testWidgets('Profile shows loading, offline, unauthorized, empty and retry', (
    tester,
  ) async {
    final h = _Harness()..mock();
    await h.open(tester);
    final pending = Completer<TransportResponse>();
    h.mock(profile: () => pending.future);
    await tester.tap(find.text('Profile'));
    await tester.pump();
    expect(find.byType(WayhunterLoadingView), findsOneWidget);
    pending.completeError(const TransportFailure());
    await _finishTransition(tester);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    h.mock(profile: () => const TransportResponse(401, []));
    await _tap(tester, 'Retry');
    expect(
      find.text('Your account cannot access this information.'),
      findsOneWidget,
    );
    h.mock(profile: () => _json(null));
    await _tap(tester, 'Retry');
    expect(find.text('No profile details available'), findsOneWidget);
  });

  testWidgets(
    'Edit Profile sends only supported fields and refreshes Profile',
    (tester) async {
      final h = _Harness();
      var profile = _profile(false);
      h.mock(
        profile: () => _json(profile),
        updateProfile: (request) {
          expect(request.headers['Authorization'], 'Bearer synthetic-owner');
          expect(jsonDecode(request.body!), {
            'displayName': 'Updated visitor',
            'bio': null,
          });
          profile = {...profile, 'displayName': 'Updated visitor', 'bio': null};
          return _json(profile);
        },
      );
      await h.open(tester);
      await _tap(tester, 'Profile');
      await _tap(tester, 'Edit Profile');
      expect(find.text('First visitor'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, ' ');
      await _tap(tester, 'Save profile');
      expect(
        h.transport.requests.where((r) => r.method == ApiMethod.put),
        isEmpty,
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        ' Updated visitor ',
      );
      await tester.enterText(find.byType(TextFormField).last, '');
      await _tap(tester, 'Save profile');
      expect(find.text('Updated visitor'), findsOneWidget);
      expect(find.text('Synthetic bio'), findsNothing);
    },
  );

  test(
    'ad adapter uses the exact bearer query and filters ineligible and unsafe assets',
    () async {
      final h = _Harness();
      await h.session.authenticate(_Harness.credential);
      h.mock(
        ads: (_) => _json([
          _ad(),
          _ad(enabled: false),
          _ad(placement: 2),
          _ad(status: 2),
          _ad(image: 'http://images.example.invalid/banner.png'),
          _ad(image: 'https://127.0.0.1/banner.png'),
          _ad(image: 'https://images.example.invalid:444/banner.png'),
          _ad(destination: 'javascript:invalid'),
        ]),
      );
      final ads = await HomeAdvertisementsApi(h.api, h.session).read();
      final request = h.transport.requests.single;
      expect(request.method, ApiMethod.get);
      expect(request.uri.path, _ads);
      expect(request.uri.queryParameters, {'placement': 'HomeBanner'});
      expect(request.headers['Authorization'], 'Bearer synthetic-owner');
      expect(ads, hasLength(2));
      expect(ads.first.imageUrl.host, 'images.example.invalid');
      expect(ads.first.destinationUrl?.host, 'www.example.invalid');
      expect(ads.last.destinationUrl, isNull);
      expect(ads.first.startAtUtc.isUtc, isTrue);
      h.session.dispose();
    },
  );

  testWidgets('banner image failure has a fallback without a click target', (
    tester,
  ) async {
    final ad = HomeAdvertisement.eligible(_ad())!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeBanner(advertisements: [ad])),
      ),
    );
    await tester.runAsync(() async {
      final stream = tester
          .widget<Image>(find.byType(Image))
          .image
          .resolve(ImageConfiguration.empty);
      final failed = Completer<void>();
      final listener = ImageStreamListener(
        (_, _) => failed.complete(),
        onError: (_, _) => failed.complete(),
      );
      stream.addListener(listener);
      await failed.future;
      stream.removeListener(listener);
    });
    await _finishTransition(tester);
    expect(find.text('Advertisement image unavailable'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets(
    'Home retry starts authenticated refresh with eligibility filtering',
    (tester) async {
      final h = _Harness()..mock(ads: (_) => const TransportResponse(503, []));
      await h.open(tester);
      expect(find.text('Could not load advertisements'), findsOneWidget);
      await _advanceRefresh(tester);
      expect(h.adRequests, hasLength(1));

      h.mock(ads: (_) => _json([_ad()]));
      await _tap(tester, 'Retry');
      expect(find.text('Synthetic Home banner'), findsOneWidget);
      expect(h.adRequests, hasLength(2));

      h.mock(
        ads: (_) => _json([
          _ad(title: 'Updated ad'),
          _ad(title: 'Disabled ad', enabled: false),
        ]),
      );
      await tester.pump(const Duration(seconds: 14));
      expect(h.adRequests, hasLength(2));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(h.adRequests, hasLength(3));
      expect(find.text('Updated ad'), findsOneWidget);
      expect(find.text('Synthetic Home banner'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Disabled ad'), findsNothing);

      h.mock(ads: (_) => const TransportResponse(503, []));
      await tester.pump(const Duration(seconds: 12));
      await tester.pump();
      expect(find.text('Updated ad'), findsOneWidget);
      expect(find.text('Could not load advertisements'), findsNothing);

      h.mock();
      await _advanceRefresh(tester);
      expect(find.text('No active advertisements'), findsOneWidget);
      expect(find.text('Updated ad'), findsNothing);

      h.mock(ads: (_) => _json([_ad(title: 'Recovered ad')]));
      await _advanceRefresh(tester);
      expect(find.text('Recovered ad'), findsOneWidget);
      expect(h.adRequests, hasLength(6));
      for (final request in h.adRequests) {
        expect(request.method, ApiMethod.get);
        expect(request.uri.queryParameters, {'placement': 'HomeBanner'});
        expect(request.headers['Authorization'], 'Bearer synthetic-owner');
      }
    },
  );

  testWidgets(
    'Home tab stops polling and reuses a pending read when reopened',
    (tester) async {
      final h = _Harness()..mock(ads: (_) => _json([_ad()]));
      await h.open(tester);
      final pending = Completer<TransportResponse>();
      h.mock(ads: (_) => pending.future);
      await _advanceRefresh(tester);
      expect(h.adRequests, hasLength(2));

      await _tap(tester, 'Profile');
      expect(find.byType(HomeBanner), findsNothing);
      await _tap(tester, 'Home');
      expect(h.adRequests, hasLength(2));
      pending.complete(_json([_ad(title: 'Shared response')]));
      await tester.pump();
      expect(find.text('Shared response'), findsOneWidget);

      await _tap(tester, 'Profile');
      await tester.pump(const Duration(seconds: 45));
      expect(h.adRequests, hasLength(2));
      h.mock();
      await _tap(tester, 'Home');
      expect(h.adRequests, hasLength(3));
      expect(find.text('No active advertisements'), findsOneWidget);
      await _advanceRefresh(tester);
      expect(h.adRequests, hasLength(4));
    },
  );

  testWidgets('Home polls only on the current route in the foreground', (
    tester,
  ) async {
    final h = _Harness()..mock();
    await h.open(tester);
    await tester.pump(const Duration(seconds: 10));
    await _tap(tester, 'Notifications');
    expect(find.text('No notifications'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(h.adRequests, hasLength(1));

    await tester.pageBack();
    await _finishTransition(tester);
    expect(find.byType(HomeBanner), findsOneWidget);
    await _advanceRefresh(tester);
    expect(h.adRequests, hasLength(2));

    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 45));
    expect(h.adRequests, hasLength(2));

    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 14));
    expect(h.adRequests, hasLength(2));
    await tester.pump(const Duration(seconds: 1));
    expect(h.adRequests, hasLength(3));
  });

  testWidgets('logout and replacement account discard a late ad refresh', (
    tester,
  ) async {
    final h = _Harness()
      ..mock(ads: (_) => _json([_ad(title: 'First account ad')]));
    await h.open(tester);
    final stale = Completer<TransportResponse>();
    h.mock(
      ads: (other) =>
          other ? _json([_ad(title: 'Second account ad')]) : stale.future,
    );
    await _advanceRefresh(tester);
    expect(h.adRequests, hasLength(2));
    await _tap(tester, 'Profile');
    await _tap(tester, 'Sign out');
    expect(find.text('First account ad'), findsNothing);
    expect(find.byType(HomeBanner), findsNothing);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'second@example.invalid');
    await tester.enterText(fields.last, 'SyntheticPassword42');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await _finishTransition(tester);
    expect(find.text('Second account ad'), findsOneWidget);
    expect(h.adRequests, hasLength(3));

    stale.complete(_json([_ad(title: 'Late first account ad')]));
    await tester.pump();
    expect(find.text('First account ad'), findsNothing);
    expect(find.text('Late first account ad'), findsNothing);
    expect(find.text('Second account ad'), findsOneWidget);
    await _advanceRefresh(tester);
    expect(h.adRequests, hasLength(4));
    expect(
      h.adRequests.last.headers['Authorization'],
      'Bearer synthetic-other',
    );
  });

  testWidgets('ads retry and account switch discard earlier private content', (
    tester,
  ) async {
    final h = _Harness();
    h.mock(ads: (_) => const TransportResponse(503, []));
    await h.open(tester);
    expect(find.text('Could not load advertisements'), findsOneWidget);
    h.mock();
    await _tap(tester, 'Retry');
    expect(find.text('No active advertisements'), findsOneWidget);

    final staleAds = Completer<TransportResponse>();
    h.mock(ads: (other) => other ? _json([]) : staleAds.future);
    await _tap(tester, 'Profile');
    await tester.tap(find.text('Home'));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is WayhunterLoadingView &&
            widget.label == 'Loading advertisements',
      ),
      findsOneWidget,
    );
    await _tap(tester, 'Profile');
    expect(find.text('first@example.invalid'), findsOneWidget);
    await _tap(tester, 'Sign out');
    staleAds.complete(_json([_ad()]));
    await _finishTransition(tester);
    expect(find.text('first@example.invalid'), findsNothing);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'second@example.invalid');
    await tester.enterText(fields.last, 'SyntheticPassword42');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await _finishTransition(tester);
    expect(find.text('Hello, Second visitor'), findsOneWidget);
    expect(find.text('Synthetic Home banner'), findsNothing);
    await _tap(tester, 'Profile');
    expect(find.text('second@example.invalid'), findsOneWidget);
    expect(find.text('first@example.invalid'), findsNothing);
  });

  test(
    'profile rejects a different owner and late results after logout',
    () async {
      final h = _Harness();
      await h.session.authenticate(_Harness.credential);
      final api = MyProfileApi(h.api, h.session);
      h.mock(profile: () => _json(_profile(true)));
      await expectLater(
        api.read(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiError.forbidden,
          ),
        ),
      );
      final pending = Completer<TransportResponse>();
      h.mock(profile: () => pending.future);
      final result = expectLater(
        api.read(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiError.unauthorized,
          ),
        ),
      );
      await h.session.clear();
      pending.complete(_json(_profile(false)));
      await result;
      h.session.dispose();
    },
  );
}
