import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/router/route_registration.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/advertisements/data/home_advertisements_api.dart';
import 'package:wayhunter_mobile/features/auth/data/identity_api.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_flow.dart';
import 'package:wayhunter_mobile/features/home/presentation/views/home_screen.dart';
import 'package:wayhunter_mobile/features/notifications/data/notifications_api.dart';
import 'package:wayhunter_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:wayhunter_mobile/features/profile/data/my_profile_api.dart';
import 'package:wayhunter_mobile/features/profile/presentation/my_profile_screen.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/data/trip_sessions_api.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/presentation/active_trip_screen.dart';
import 'package:wayhunter_mobile/features/traveller/planning/data/trip_plans_api.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_plan.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/traveller_screens.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/trip_editor.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';
import 'package:wayhunter_mobile/shared/widgets/starter_placeholder.dart';

const person1AuthRoute = 'auth.signIn';

Map<String, RouteRegistration<Object?>> person1Routes(
  ValueChanged<ModuleId> selectModule,
) {
  TripSessionsApi? sessions;
  TripSessionsApi lifecycle(FoundationServices services) {
    final current = sessions;
    if (current != null && current.belongsTo(services.session)) return current;
    return sessions = TripSessionsApi(services.api, services.session);
  }

  return {
    person1AuthRoute: RouteRegistration<Null>((context, _) {
      final services = FoundationServices.of(context);
      return AuthFlow(
        api: IdentityApi(services.api),
        session: services.session,
      );
    }),
    AppRoutes.home: RouteRegistration<Null>((context, _) {
      final services = _foundation(context);
      return HomeScreen(
        onSelectModule: selectModule,
        profileApi: services == null
            ? null
            : MyProfileApi(services.api, services.session),
        advertisementsApi: services == null
            ? null
            : HomeAdvertisementsApi(services.api, services.session),
      );
    }),
    AppRoutes.traveller: RouteRegistration<Null>(
      (_, _) => const TravellerHome(),
    ),
    createTripRoute: RouteRegistration<Null>(
      (context, _) => _planning(context, (api) => TripEditor(api: api)),
    ),
    myTripPlansRoute: RouteRegistration<Null>(
      (context, _) => _planning(context, (api) => MyTripPlans(api: api)),
    ),
    AppRoutes.profile: RouteRegistration<Null>((context, _) {
      final services = _foundation(context);
      return MyProfileScreen(
        api: services == null
            ? null
            : MyProfileApi(services.api, services.session),
      );
    }),
    notificationsRoute: RouteRegistration<Null>(
      (context, _) => _withFoundation(
        context,
        (services) => NotificationsScreen(
          api: NotificationsApi(services.api, services.session),
          plans: TripPlansApi(services.api, services.session),
        ),
      ),
    ),
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
      (context, plan) => _withFoundation(
        context,
        (services) => SavedTripDetails(
          api: TripPlansApi(services.api, services.session),
          reference: plan,
          sessions: lifecycle(services),
        ),
      ),
      validate: (plan) => isTripPlanId(plan.id),
    ),
    AppRoutes.activeTrip: RouteRegistration<ActiveTripArgs>(
      (context, args) => _withFoundation(
        context,
        (services) => ActiveTripScreen(
          reference: args,
          plans: TripPlansApi(services.api, services.session),
          sessions: lifecycle(services),
        ),
      ),
      validate: (trip) =>
          isTripPlanId(trip.plan.id) && isTripPlanId(trip.session.id),
    ),
  };
}

Widget _planning(BuildContext context, Widget Function(TripPlansApi) builder) =>
    _withFoundation(
      context,
      (services) => builder(TripPlansApi(services.api, services.session)),
    );

Widget _withFoundation(
  BuildContext context,
  Widget Function(FoundationServices) builder,
) {
  final services = _foundation(context);
  if (services == null) return const WayhunterUnavailableView();
  return builder(services);
}

FoundationServices? _foundation(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<FoundationServices>();
