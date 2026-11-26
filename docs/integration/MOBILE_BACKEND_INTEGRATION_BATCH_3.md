# Mobile backend integration Batch 3

Flutter `feature/mobile-backend-integration-batch3` starts at `c12960c485d377048b010e9d05b779e69c21417a`, the verified GitHub `devlop` head containing PR #18. The verified backend `develop` head is `1db99995c1049fe136c245d3e73c64d258ad1929`. **SOURCE** means the Active Rules and the draft Master BRD. **CODE_VERIFIED** means the pinned ASP.NET implementation and Flutter code were inspected. **BLOCKED** marks checks or work that require an authorized environment, provider, or missing contract. **DECISION_REQUIRED** identifies contract or approval work. [Backend source](https://github.com/naanga7peru/Wayhunter_mobile_application_Backend/tree/1db99995c1049fe136c245d3e73c64d258ad1929) · [Batch 1 audit](MOBILE_BACKEND_INTEGRATION_BATCH_1.md) · [Batch 2 audit](MOBILE_BACKEND_INTEGRATION_BATCH_2.md)

## Auth and Android

- The Android main manifest supplies Internet permission. Bootstrap reads the HTTPS origin from `WAYHUNTER_API_BASE_URL`, namespaces encrypted credentials by environment and origin, and uses the platform trust chain. The transport disables redirects, attaches bearer credentials only to protected requests and times out after 15 seconds. Failed reads can be retried explicitly.
- `POST /api/mobile/identity/login` supplies an expiry. Startup verifies restored ownership through `GET /api/mobile/identity/me`. `POST /api/mobile/auth/logout` attempts revocation, then local credentials are cleared. A 401 for the current protected session now closes the shell and clears local credentials, including through the storage-failure retry path. A delayed 401 from the replaced session is ignored. A protected resource 403 remains a local denial. A startup /me 403 still invalidates the saved credential. The backend does not expose mobile token refresh.

## Person 1

| Verified contract | Flutter result or dependency |
| --- | --- |
| `POST /api/mobile/trip-plans`, `GET /api/mobile/trip-plans`, `GET/PUT/DELETE /api/mobile/trip-plans/{tripPlanId}`, `POST /api/mobile/trip-plans/{tripPlanId}/stops`, `PUT /api/mobile/trip-plans/{tripPlanId}/stops/order`, `DELETE /api/mobile/trip-plans/{tripPlanId}/stops/{stopId}` | PR #18 already sends paired stop coordinates and optional place IDs, sorts server stops, and uses RowVersion and strong If-Match. **BLOCKED** for persistence and conflicts on Android with deployed TravelPlanning storage. |
| `POST /api/mobile/trips/{tripPlanId}/invitations`, `GET /api/mobile/trip-invitations/pending`, `POST /api/mobile/trip-invitations/{invitationId}/{accept,reject,cancel}`, `DELETE /api/mobile/trips/{tripPlanId}/members/{memberUserId}` | Existing invite flow uses authenticated actors. The invitation store and eligibility dependencies are deployment requirements. Accepting membership has separate GPS consent. |
| `PUT /api/mobile/trips/{tripPlanId}/sessions/{sessionId}/gps-consent`, `/hubs/trip-location` | `SetMyTripGpsConsentRequest.isGranted` requires eligible accepted membership and a matching, unfinished session. The verified HTTP controller supplies a setter. **DECISION_REQUIRED** for consent status lookup and member navigation, and **BLOCKED** for GPS grant, publishing and subscription integration. |
| `POST /api/mobile/trips/{tripPlanId}/sessions`, `POST /api/mobile/trips/{tripPlanId}/sessions/{sessionId}/{pause,resume,finish}`, `GET /api/mobile/trips/{tripPlanId}/sessions/{sessionId}/recover` | Flutter stores an encrypted marker before Start or Finish, scoped by environment, origin, owner and trip. A lost Start requires a server-confirmed session ID. A lost Finish preserves its ID so reopening can read it. Only a validated Active/Paused recovery clears an uncertain result. A recovery 404 leaves the app unable to attest completion. **DECISION_REQUIRED** for a trip-scoped session lookup and an authoritative terminal response. |
| `POST /api/mobile/trips/{tripPlanId}/sessions/{sessionId}/im-safe` | Owner Active/Paused screen sends a bodyless request. It displays the server timestamp only after checking the check-in ID, user, trip, and session. A deliberate retry can receive the same logical receipt because the store deduplicates by user and session. **BLOCKED** live pending `TripSafety:EnableSafeCheckIn`, `TripSafety:EnableSqlPersistence` and deployed notification dependencies. |
| `GET /api/mobile/trips/{tripPlanId}/hazards`, `POST /api/mobile/trips/{tripPlanId}/hazards` | Both saved planning and Active Trip can open warnings. The backend calculates route geometry from ordered coordinate stops and matches within 1 km for 24 hours after report time. Flutter shows photo capture and server report timestamps and suppresses expired entries. Empty may indicate missing geometry, missing provider or no match. **BLOCKED** for live Google Routes and approved private hazard capture/upload. |
| `GET /api/mobile/trips/{tripPlanId}/memories[/{memoryId}]`, `POST /api/mobile/trips/{tripPlanId}/memories`, `DELETE /api/mobile/trips/{tripPlanId}/memories/{memoryId}` | Existing private text memories now retry with an identical operation ID and caption after an unconfirmed response in the open form. **BLOCKED** live pending `TripSafety:EnableSqlTripMemories`. Private upload grant and completion routes require a configured media provider. |

### Human review fix for Start and Finish rejection

The ASP.NET controller and registered services reject unauthenticated requests, failed owner checks, and invalid or missing trip/session inputs before persisting a mutation. A Start or Finish HTTP 400, 401, 403 or 404 clears the marker for that dispatched operation. In particular, the client expires a rejected session before the trip adapter catches a 401. The adapter clears using the owner and trip captured before dispatch. The owner/trip guard is shared by adapters using the same recovery store, so a replacement sign-in cannot begin a competing mutation or reconciliation until cleanup completes. [Backend controller](https://github.com/naanga7peru/Wayhunter_mobile_application_Backend/blob/1db99995c1049fe136c245d3e73c64d258ad1929/src/Wayhunter.Api/Controllers/Mobile/TripSafety/TripSafetyMobileActionsController.cs)

Timeout, network loss, 5xx, conflict, invalid responses, and recovery 404 keep the pending marker. A secure-storage deletion error is surfaced. The process keeps the owner/trip blocked even if the deletion took effect, and attempts to restore the marker if the store reports it missing. If the marker is missing and restoration also fails, the fallback block lasts for the running process.

## Person 2

| Verified contract | Flutter result or dependency |
| --- | --- |
| `GET /api/mobile/hunter/places`, `GET /api/mobile/hunter/submissions`, `GET /api/mobile/hunter/submissions/{submissionId}` | Batch 2 authenticated discovery and owner history remain available. Trusted identity and authoritative Hunter SQL reads are required. Review reasons are absent from the mobile status projection. |
| `POST /api/mobile/hunter/submissions`, `PUT/DELETE /api/mobile/hunter/submissions/{submissionId}`, `POST /api/mobile/hunter/submissions/{submissionId}/{capture-sessions,evidence,submit}` | The backend resolves the owner from claims. Capture starts for an eligible owned Draft. Evidence binding requires a capture-session ID, evidence type and provider receipt. The verifier is wired to `DisabledHunterMediaReceiptVerifier`. The device's camera file and GPS reading do not establish trusted evidence. **BLOCKED** pending reviewed native flow, private upload/receipt issuance and verification, trusted location policy, and staging checks for the live guided video and normal photo. |
| `GET /api/mobile/games`, `GET /api/mobile/games/{gameId}`, `GET /api/mobile/games/me/attempts`, `GET /api/mobile/games/me` | Player history now explicitly refreshes the owner’s server progress and validates attempt chronology. Creator history displays `Expired` as Archived. Reads require `Games:EnableSqlPersistence`. The persistent archive worker additionally uses `Games:EnableExpiryWorker`. |
| `POST /api/mobile/games/{gameId}/attempts`, `POST /api/mobile/games/drafts`, `GET/PUT/DELETE /api/mobile/games/drafts/{gameId}`, `POST /api/mobile/games/drafts/{gameId}/submit` | Separate start/resume attempt writer uses Development, Games SQL and `Games:EnableSqlAttemptWriter`. Draft registration uses shared auth and either Games SQL or Development with `Games:EnableDevelopmentDraftHttpApi`. Draft create needs `Idempotency-Key` and versioned update needs `If-Match`. **BLOCKED** for approval and trusted player proof, finish and winner HTTP contracts. Attempt GET only refreshes status. |
| `GET /api/mobile/coins-wallet/me`, `GET /api/mobile/coins-wallet/me/transactions?kind=Reward&page={page}&pageSize={pageSize}`, `GET /api/mobile/coins-wallet/vouchers/offers[/{offerId}]`, `GET /api/mobile/coins-wallet/vouchers/requests/{requestId}[/issued-voucher]` | Wallet uses server balance, rewards, eligibility, request state and owner-only issued data. Voucher writes remain gated. **BLOCKED** for live SQL ledger and voucher runtime, issued sample artwork delivery, and a reviewed academic redemption run. |

## M7 Home and publication

- **CODE_VERIFIED** `GET /api/mobile/home` authenticates and checks an active account. It returns owner profile summary, nullable wallet, up to five upcoming owned trips, available games, approved Hunter places, Home banners and sponsored POIs. The summary profile lacks the avatar from `/identity/me`, and the aggregate does its reads as one operation. Flutter retains independent Home profile and PR #16 banner requests so a failure in another aggregate section cannot suppress the banner or profile. **DECISION_REQUIRED** for an aggregate Home layout.
- **CODE_VERIFIED** `PATCH /api/admin/advertisements/{advertisementId}/status` requires Admin authorization and accepts `AdvertisementStatusUpdateRequest.status` for Active, Paused or Archived. Image publication uses `POST /api/admin/advertisements/{advertisementId}/image` with a configured image provider. Mobile `GET /api/mobile/advertisements/active?placement=HomeBanner` filters against server time and placement. Flutter retains PR #16 refresh and HTTPS image validation. **BLOCKED** on a test Admin, authorized staging ad and configured advertisement storage and image provider.

## Authorized Android staging checklist

1. Obtain approval for a non-production HTTPS origin reachable by the Android device and two test accounts. Use a certificate with the deployed hostname in its SAN and a chain trusted by Android. If staging uses a developer HTTPS proxy, keep its HTTP upstream private. Supply credentials interactively through the app or the approved Admin UI. Keep them out of build arguments, screen captures and diagnostic logs.
2. Select the authorized environment and build for the intended device. Use an origin without the `/api` suffix.

   ```powershell
   $wayhunterStagingOrigin = Read-Host 'Authorized Wayhunter HTTPS origin'
   $wayhunterAndroidDevice = Read-Host 'Authorized Android device ID'
   flutter run -d $wayhunterAndroidDevice --dart-define=WAYHUNTER_ENV=staging "--dart-define=WAYHUNTER_API_BASE_URL=$wayhunterStagingOrigin"
   ```

3. Sign in as A, restart the Android process, check ownership, sign out, and sign in as B. Verify scoped 403 behavior and use an authorized test account with a revoked or expired session to verify 401 clearing. With transient network loss, verify read retry, then reconnect. Record status codes and results without bearer credentials or private payloads.
4. Use A’s designated test trip to save and reopen two ordered pins. Exercise a stale version using two authorized clients. Check invitation acceptance independently of GPS consent. For lost Start or Finish, use an approved staging fault harness and verify that recovery is read-only until an authoritative response. Recovery markers survive an app restart on the same installation. After a reinstall, another device, or cleared storage, reconcile with the backend before retrying. Check Safe Check-in once per user/session, privately scoped text Memories, and eligible, ineligible, and expired hazard cases with configured Routes.
5. Read approved Hunter Places, owner-scoped Hunt and Game history, an archived Game, and Wallet rewards and a test voucher via a pre-existing request ID. Confirm B cannot see A’s protected records. For M7, ask the authorized staging Admin to publish and pause a designated test banner. Verify the regular Home refresh reflects both changes. Record the deployed backend revision, device/Android version, and redacted observations.

**BLOCKED** for all device-to-backend and Admin-to-device verification in this workspace. The available endpoint and application tests are source and mocked evidence. The non-staging debug APK is a compilation check.

## Changed files

- **Foundation and auth** — `lib/app/bootstrap/bootstrap.dart`, `lib/app/bootstrap/foundation_services.dart`, `lib/app/router/person1_routes.dart`, `lib/core/auth/session_controller.dart`, `lib/core/network/api_client.dart`, `lib/features/auth/presentation/auth_gate.dart`.
- **Traveller and safety** — `lib/features/traveller/active_trip/data/trip_recovery_store.dart`, `lib/features/traveller/active_trip/data/trip_sessions_api.dart`, `lib/features/traveller/active_trip/presentation/active_trip_screen.dart`, `lib/features/traveller/planning/presentation/traveller_screens.dart`, `lib/features/safety/domain/hazard_warning.dart`, `lib/features/safety/presentation/safety_screens.dart`, `lib/features/memories/presentation/memories_screens.dart`.
- **Games** — `lib/features/games/data/api_games_reader.dart`, `lib/features/games/presentation/game_read_screens.dart`.
- **Tests** — `test/person1/active_trip_lifecycle_test.dart`, `test/person1/safety_memories_test.dart`, `test/person1/startup_auth_gate_test.dart`, `test/widget/games/game_screens_test.dart`.
- **Audit and staging runbook** — `docs/integration/MOBILE_BACKEND_INTEGRATION_BATCH_3.md`.

## Validation

- `flutter analyze` passed with no issues.
- `dart format` passed on the two Dart files modified for the human review fix.
- `flutter test --reporter expanded` passed all 264 tests. The review regressions cover Start after reauthentication, definite Finish rejection, durable timeout markers, account isolation, same-owner overlap, ambiguous responses, and failed storage cleanup. Transport and platform storage were mocked.
- `flutter build apk --debug` produced `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` passed. `git status -sb` listed the uncommitted review changes on `feature/mobile-backend-integration-batch3`.
