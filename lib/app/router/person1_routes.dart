import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/router/route_registration.dart';
import 'package:wayhunter_mobile/features/auth/data/identity_api.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_flow.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_gate.dart';
import 'package:wayhunter_mobile/features/home/presentation/views/home_screen.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';
import 'package:wayhunter_mobile/shared/widgets/starter_placeholder.dart';

const person1AuthRoute = 'auth.signIn';

Map<String, RouteRegistration<Object?>> person1Routes(
  ValueChanged<ModuleId> selectModule,
) => {
  person1AuthRoute: RouteRegistration<Null>((context, _) {
    final services = FoundationServices.of(context);
    return AuthFlow(api: IdentityApi(services.api), session: services.session);
  }),
  AppRoutes.home: RouteRegistration<Null>(
    (_, arguments) => HomeScreen(onSelectModule: selectModule),
  ),
  AppRoutes.traveller: const RouteRegistration<Null>(_traveller),
  AppRoutes.profile: const RouteRegistration<Null>(_profile),
  AppRoutes.userProfile: RouteRegistration<UserRef>(
    (_, arguments) =>
        const StarterPlaceholder(title: 'User profile', owner: 'M1'),
    validate: (user) => isNavigationId(user.id),
  ),
  AppRoutes.addPlace: RouteRegistration<PlaceRef>(
    (_, place) => StarterPlaceholder(
      title: 'Add place to trip',
      owner: 'M2',
      detail: switch (place.source) {
        PlaceSource.hunterApproved =>
          'SAMPLE PREVIEW: Hunter place (backend approval unverified)',
        PlaceSource.externalProvider => 'Source: External provider',
      },
    ),
    validate: (place) => isNavigationId(place.id),
  ),
  AppRoutes.tripPlan: RouteRegistration<TripPlanRef>(
    (_, arguments) => const StarterPlaceholder(title: 'Trip plan', owner: 'M2'),
    validate: (plan) => isNavigationId(plan.id),
  ),
  AppRoutes.activeTrip: RouteRegistration<ActiveTripArgs>(
    (_, arguments) =>
        const StarterPlaceholder(title: 'Active trip', owner: 'M3'),
    validate: (trip) =>
        isNavigationId(trip.plan.id) && isNavigationId(trip.session.id),
  ),
};

Widget _traveller(BuildContext context, Null arguments) =>
    const StarterPlaceholder(title: 'Traveler', owner: 'M2 / M3');

Widget _profile(BuildContext context, Null arguments) => SafeArea(
  child: ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
      const Text('Development preview'),
      ListTile(
        title: const Text('Wallet'),
        onTap: () => const AppDestination(AppRoutes.wallet).open(context),
      ),
      ListTile(
        title: const Text('My Hunts'),
        onTap: () => const AppDestination(AppRoutes.myHunts).open(context),
      ),
      ListTile(
        title: const Text('My Games'),
        onTap: () => const AppDestination(AppRoutes.myGames).open(context),
      ),
      const AuthSignOutTile(),
    ],
  ),
);
