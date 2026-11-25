import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/router/route_registration.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/advertisements/data/home_advertisements_api.dart';
import 'package:wayhunter_mobile/features/auth/data/identity_api.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_flow.dart';
import 'package:wayhunter_mobile/features/friends/data/trip_invitations_api.dart';
import 'package:wayhunter_mobile/features/friends/domain/trip_invitation.dart';
import 'package:wayhunter_mobile/features/friends/presentation/friends_screen.dart';
import 'package:wayhunter_mobile/features/home/presentation/views/home_screen.dart';
import 'package:wayhunter_mobile/features/memories/data/trip_memories_api.dart';
import 'package:wayhunter_mobile/features/memories/presentation/memories_screens.dart';
import 'package:wayhunter_mobile/features/notifications/data/notifications_api.dart';
import 'package:wayhunter_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:wayhunter_mobile/features/profile/data/my_profile_api.dart';
import 'package:wayhunter_mobile/features/profile/presentation/my_profile_screen.dart';
import 'package:wayhunter_mobile/features/safety/data/trip_hazards_api.dart';
import 'package:wayhunter_mobile/features/safety/presentation/safety_screens.dart';
import 'package:wayhunter_mobile/features/settings/presentation/settings_screen.dart';
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
  TripInvitationsApi? invitations;
  TripInvitationsApi friends(FoundationServices services) {
    final current = invitations;
    if (current != null && current.belongsTo(services.session)) return current;
    return invitations = TripInvitationsApi(services.api, services.session);
  }

  TripSessionsApi? sessions;
  TripSessionsApi lifecycle(FoundationServices services) {
    final current = sessions;
    if (current != null && current.belongsTo(services.session)) return current;
    return sessions = TripSessionsApi(services.api, services.session);
  }

  HomeAdvertisementsApi? homeAdvertisements;
  HomeAdvertisementsApi advertisements(FoundationServices services) {
    final current = homeAdvertisements;
    if (current != null && current.uses(services.api, services.session)) {
      return current;
    }
    return homeAdvertisements =
        HomeAdvertisementsApi(services.api, services.session);
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
            : advertisements(services),
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
    friendsRoute: RouteRegistration<Null>(
      (context, _) => _withFoundation(
        context,
        (services) => FriendsScreen(api: friends(services)),
      ),
    ),
    tripFriendsRoute: RouteRegistration<TripPlanRef>(
      (context, trip) => _withFoundation(
        context,
        (services) => FriendsScreen(api: friends(services), trip: trip),
      ),
      validate: (trip) => isInvitationGuid(trip.id),
    ),
    settingsRoute: RouteRegistration<Null>(
      (context, _) => _withFoundation(
        context,
        (services) => SettingsScreen(
          permissions: services.permissions,
          notifications: NotificationsApi(services.api, services.session),
        ),
      ),
    ),
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
    tripSafetyRoute: RouteRegistration<TripPlanRef>(
      (context, plan) => _withFoundation(
        context,
        (services) => TripSafetyScreen(
          plan: plan,
          api: TripHazardsApi(services.api, services.session),
        ),
      ),
      validate: (plan) => isTripPlanId(plan.id),
    ),
    tripHazardDetailsRoute: RouteRegistration<HazardDetailsArgs>(
      (context, args) =>
          _withFoundation(context, (_) => TripHazardDetailsScreen(args: args)),
      validate: (args) =>
          isTripPlanId(args.plan.id) && isTripPlanId(args.warning.id),
    ),
    tripMemoriesRoute: RouteRegistration<TripPlanRef>(
      (context, plan) => _withFoundation(
        context,
        (services) => TripMemoriesScreen(
          plan: plan,
          api: TripMemoriesApi(services.api, services.session),
        ),
      ),
      validate: (plan) => isTripPlanId(plan.id),
    ),
    tripMemoryCreateRoute: RouteRegistration<TripPlanRef>(
      (context, plan) => _withFoundation(
        context,
        (services) => TripMemoryCreateScreen(
          plan: plan,
          api: TripMemoriesApi(services.api, services.session),
        ),
      ),
      validate: (plan) => isTripPlanId(plan.id),
    ),
    tripMemoryDetailsRoute: RouteRegistration<TripMemoryDetailsArgs>(
      (context, args) => _withFoundation(
        context,
        (services) => TripMemoryDetailsScreen(
          args: args,
          api: TripMemoriesApi(services.api, services.session),
        ),
      ),
      validate: (args) =>
          isTripPlanId(args.plan.id) && isTripPlanId(args.memoryId),
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
