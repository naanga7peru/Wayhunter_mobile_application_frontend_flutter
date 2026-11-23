import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/router/route_registration.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/auth/data/identity_api.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_flow.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_gate.dart';
import 'package:wayhunter_mobile/features/home/presentation/views/home_screen.dart';
import 'package:wayhunter_mobile/features/traveller/planning/data/trip_plans_api.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_plan.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/traveller_screens.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/trip_editor.dart';
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
  AppRoutes.traveller: RouteRegistration<Null>((_, _) => const TravellerHome()),
  createTripRoute: RouteRegistration<Null>(
    (context, _) => _planning(context, (api) => TripEditor(api: api)),
  ),
  myTripPlansRoute: RouteRegistration<Null>(
    (context, _) => _planning(context, (api) => MyTripPlans(api: api)),
  ),
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
    (context, plan) => _planning(
      context,
      (api) => SavedTripDetails(api: api, reference: plan),
    ),
    validate: (plan) => isTripPlanId(plan.id),
  ),
  AppRoutes.activeTrip: RouteRegistration<ActiveTripArgs>(
    (_, arguments) =>
        const StarterPlaceholder(title: 'Active trip', owner: 'M3'),
    validate: (trip) =>
        isNavigationId(trip.plan.id) && isNavigationId(trip.session.id),
  ),
};

Widget _planning(BuildContext context, Widget Function(TripPlansApi) builder) {
  final services = context
      .dependOnInheritedWidgetOfExactType<FoundationServices>();
  if (services == null) return const WayhunterUnavailableView();
  return builder(TripPlansApi(services.api, services.session));
}

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
