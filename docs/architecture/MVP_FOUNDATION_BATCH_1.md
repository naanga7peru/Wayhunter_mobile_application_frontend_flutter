# WayHunter mobile foundation · Batch 1

Android is the primary platform. From the repository root, run `flutter run -d <android-device-id>`. The optional `--dart-define=WAYHUNTER_ENV=staging` sets the environment label. Accepted labels are `development` (default), `staging`, and `production`. The label does not enable backend capabilities. Existing Web scaffolding is available for UI development.

## Adding a route

1. Person 1 edits `lib/app/router/person1_routes.dart` for Auth, Home, Traveller, Safety, Memories, Friends, Profile, Settings, and Notifications. Person 2 edits `lib/app/router/person2_routes.dart` for Hunter, Places, Games, Coins, Wallet, Redemption, Vouchers, and Shared Leaderboard.
2. Build the destination inside your own feature, then replace its placeholder registration or add a feature-private route name in your own registrar. Use `RouteRegistration<Null>` for a route without arguments, or a typed registration with a validator. Coordinate new cross-owner route IDs and types in `app_routes.dart`. Keep existing IDs stable and use each ID in only one registrar.
3. Call across features through `AppDestination` and the shared references in `lib/shared/domain/models/navigation_refs.dart`. For example, Hunter calls `AppDestination.addPlace(PlaceRef(placeId, source: PlaceSource.hunterApproved)).open(context)`. Traveller owns the destination and its eventual authorization and data fetch.
4. Add tests for the valid input, wrong type, malformed ID, and Back behavior where relevant. Run `flutter analyze` and `flutter test`.

IDs are opaque navigation keys with a limited character set and length. Boundary checks reject malformed values. The receiving feature must still verify existence, visibility, and authorization when real data is available. Routes use in-process named navigation. URL argument decoding, restoration, and auth guards are outside Batch 1.

Home and the module, leaderboard, and profile roots render inside the shell. Named pushes open detail pages above the shell and Back restores the prior tab. Before selection the module tab opens Home and Leaderboard prompts for module selection. The shared keys cover `home`, `traveller.home`, `hunter.home`, `games.home`, `leaderboard.module`, `profile.me`, `profile.user`, `traveller.addPlace`, `traveller.plan`, `traveller.activeTrip`, `wallet.home`, `hunter.myHunts` and `games.myGames`. Unknown routes, missing registrations, duplicates, and invalid arguments show an unavailable message. Profile shortcuts and the Hunter place handoff are development previews.

Registration and OTP remain on their existing task branches. Batch 2 can build on this routing without pulling either branch into the foundation.
