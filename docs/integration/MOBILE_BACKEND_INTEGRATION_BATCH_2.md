# Mobile backend integration Batch 2

Flutter branch `feature/mobile-backend-integration-batch2` is based on `origin/devlop` at `98fee710d449977e2682afad07d91d7d760d5789` (PR #17). **CODE_VERIFIED** refers to the Flutter patch and the ASP.NET controllers, DTOs and repositories at backend `develop` commit `1db99995c1049fe136c245d3e73c64d258ad1929`. **SOURCE** refers to the Master BRD draft and the current owner rules. Automated Flutter checks use local fixtures and an injected transport. [Backend source](https://github.com/naanga7peru/Wayhunter_mobile_application_Backend/tree/1db99995c1049fe136c245d3e73c64d258ad1929) · [Active rules](../second-brain/ACTIVE_RULES.md) · [Batch 1 audit](MOBILE_BACKEND_INTEGRATION_BATCH_1.md)

## CODE_VERIFIED mobile contracts

Each endpoint requires the authenticated mobile session. The backend uses the caller's identity for owner-scoped reads.

| Module | Method and exact path | Contract and Flutter behavior |
| --- | --- | --- |
| M2 Traveller | `POST /api/mobile/trip-plans` | `CreateTripPlanDto` takes ordered `initialStops` with name, optional `placeId` and optional coordinate pair. The picker supplies latitude and longitude. Stop serialization preserves a provider ID when supplied by the caller. |
| M2 Traveller | `POST /api/mobile/trip-plans/{tripPlanId}/stops` | `AddTripStopDto` accepts the same fields and the current `expectedRowVersion` when available. An existing plan can add a stop with the same picker. |
| M2 Traveller | `GET /api/mobile/trip-plans` and `GET /api/mobile/trip-plans/{tripPlanId}` | `TripPlanResponseDto` contains ordered `TripStopResponseDto` records. Saved trip details display server coordinates. Both null coordinates are valid for manual and legacy stops. Coordinates must be paired, finite and in range. |
| M2 Traveller | `PUT /api/mobile/trip-plans/{tripPlanId}`, `PUT /api/mobile/trip-plans/{tripPlanId}/stops/order`, `DELETE /api/mobile/trip-plans/{tripPlanId}/stops/{stopId}` | Existing trip edit and reorder send `expectedRowVersion` as in Batch 1. Stop removal sends a quoted strong `If-Match` when a version is available. |
| M1 Profile | `GET /api/mobile/identity/me`, `PUT /api/mobile/identity/me` | `UpdateMyProfileRequest` accepts display name (1–200 characters after trimming) and optional bio (up to 500). Flutter checks the `PrivateProfileDto` owner on both operations. |
| M4 Hunter | `GET /api/mobile/hunter/places` | `ApprovedHunterPlaceDto[]` is the approved discovery projection. Flutter validates the ID, district, timestamp and coordinates and renders the place name and district. |
| M4 Hunter | `GET /api/mobile/hunter/submissions`, `GET /api/mobile/hunter/submissions/{submissionId}` | `HunterSubmissionResponseDto[]` includes the submission ID. `HunterSubmissionStatusResponse` omits the ID and review reason. The server returns 404 for either a missing or a foreign submission. Flutter displays the verified Draft, Pending, Held, Approved and Rejected status values. |
| M5 Games | `GET /api/mobile/games/me` | `MyGameDto[]` is the creator's history. The backend enum's `Expired` maps to Archived in Flutter. The history retains rows after expiry and exposes no play or draft action. |
| M6 Wallet | `GET /api/mobile/coins-wallet/vouchers/offers/{offerId}` | `SampleVoucherOfferResponse` contains current eligibility, stock, validity and pricing. The details view checks the returned ID and uses the current response. |
| M6 Wallet | `GET /api/mobile/coins-wallet/me/transactions?page={page}&pageSize={pageSize}&kind=Reward` | `CoinTransactionHistoryResponse` supplies paged reward-only results and server reward types and timestamps. General transaction history continues to omit the kind filter. |

The existing `GET /api/mobile/coins-wallet/vouchers/offers`, `GET /api/mobile/coins-wallet/vouchers/requests/{requestId}` and `GET /api/mobile/coins-wallet/vouchers/requests/{requestId}/issued-voucher` remain available. Request and issuance lookup require a known request ID. The normal app route binds the read-only repository and hides request creation and cancellation controls. This respects the approved VCH-DEC-01 reserve, approval-debit and issuance flow while keeping monetary operations outside this batch.

## BLOCKED and DECISION_REQUIRED

- **BLOCKED — Live verification.** Requires an authorized HTTPS staging origin trusted by Android, two authorized test accounts and deployed module backing stores. Device-to-backend, Google Maps on-device configuration, real account isolation, SQL persistence across restarts, archive-worker behavior, and Admin-to-mobile publication remain unverified. Backend source and a debug APK are independent evidence.
- **DECISION_REQUIRED — Additional fields.** The picker returns a map point and exposes no Google Places ID. Other profile changes need a verified update contract. The Hunter detail DTO and creator Game history omit Admin review reasons.
- **DECISION_REQUIRED — Workflow authorization.** Hunter capture/evidence and Game draft/proof flows need separately reviewed contracts and provider configuration. Voucher mutations need explicit approval for a controlled academic demo run.

## Changed files

- **Shared routing and validation** — `lib/app/router/person2_routes.dart`, `lib/core/network/api_dto.dart`, `lib/core/network/session_api.dart`, `lib/shared/domain/models/coordinates.dart`.
- **Traveller planning** — `lib/features/traveller/planning/data/trip_plans_api.dart`, `domain/trip_plan.dart`, `presentation/traveller_screens.dart`, `presentation/trip_editor.dart` under the same module.
- **Profile** — `lib/features/profile/data/my_profile_api.dart`, `lib/features/profile/presentation/my_profile_screen.dart`.
- **Hunter** — `lib/features/hunter/data/api_hunter_reader.dart`, `lib/features/hunter/domain/hunter_history.dart`, `lib/features/hunter/presentation/hunter_screens.dart`.
- **Games** — `lib/features/games/data/api_games_reader.dart`, `lib/features/games/domain/games_reader.dart`, `lib/features/games/presentation/my_games.dart`.
- **Wallet** — `lib/features/wallet/data/repositories/api_wallet_reader.dart`, `lib/features/wallet/domain/repositories/wallet_reader.dart`, `lib/features/wallet/presentation/wallet_screens.dart`, `lib/features/wallet/presentation/wallet_redemption_screens.dart`.
- **Tests** — `test/person1/trip_planning_test.dart`, `test/person1/home_profile_ads_test.dart`, `test/person1/startup_auth_gate_test.dart`, `test/games/api_games_reader_test.dart`, `test/wallet/api_wallet_reader_test.dart`, `test/widget/games/game_screens_test.dart`, `test/widget/hunter/api_hunter_reader_test.dart`, `test/widget/hunter/hunter_screens_test.dart`, `test/widget/wallet/wallet_screens_test.dart`, `test/widget/M7/home_leaderboard_qa_test.dart`.
- **Integration record** — `docs/integration/MOBILE_BACKEND_INTEGRATION_BATCH_2.md`.

## Validation

- `flutter analyze` passed with no issues.
- `flutter test --reporter expanded` passed all 248 tests. The suite covers the picker-to-request round trip, malformed coordinates, Profile updates, authenticated reads and account replacement with injected transports.
- `flutter build apk --debug` produced `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` passed. `git status -sb` showed the Batch 2 changes in the working tree for human code review.
