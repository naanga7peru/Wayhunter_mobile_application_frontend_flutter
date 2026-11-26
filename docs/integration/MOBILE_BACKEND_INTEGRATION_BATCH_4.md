# Mobile backend integration Batch 4

Flutter `feature/mobile-final-e2e-integration` started clean at `046417d` (merged PR #19). GitHub compares reported that this base matches `devlop` and that backend `develop` matches `1db99995c1049fe136c245d3e73c64d258ad1929`. **SOURCE** means the BRD and current owner rules. **CODE_VERIFIED** means inspected implementation at those revisions or in this Flutter patch. **BLOCKED** means a missing environment, dependency, permission, or contract. **DECISION_REQUIRED** marks remaining contract work. [Backend source](https://github.com/naanga7peru/Wayhunter_mobile_application_Backend/tree/1db99995c1049fe136c245d3e73c64d258ad1929) · [Active rules](../second-brain/ACTIVE_RULES.md) · [Batch 1](MOBILE_BACKEND_INTEGRATION_BATCH_1.md) · [Batch 2](MOBILE_BACKEND_INTEGRATION_BATCH_2.md) · [Batch 3](MOBILE_BACKEND_INTEGRATION_BATCH_3.md)

**Live Android E2E is BLOCKED.** This checkout has no supplied authorized staging HTTPS origin or authorized account pair. Local ADB reported zero attached devices, including zero ready physical Android devices. No staging requests, logins, Admin actions, or database operations were executed. Tests use injected transports and device or storage fakes. The debug APK is build evidence.

## Completed frontend work

Saved trips now expose **Review route** below the stop editor. A user-initiated review sends the server’s saved stop coordinates in stop order to the authenticated, compute-only route-preview endpoint. The runtime provider contract requires 2–27 stops with valid coordinate pairs. The screen shows validated provider distance, estimated travel time, and stop order. The estimate excludes live traffic. Invalid geometry or estimates fail closed. A 503 or network failure can be retried explicitly, and a 429 shows a quota message. Plans with missing pins or an unsupported stop count skip the provider call. [Route preview controller](https://github.com/naanga7peru/Wayhunter_mobile_application_Backend/blob/1db99995c1049fe136c245d3e73c64d258ad1929/src/Wayhunter.Api/Controllers/Mobile/TravelPlanning/RoutePreviewController.cs)

The trip-plan adapter also rejects a response tied to a superseded authenticated session, even when the same owner signs back in with the same token string. The existing Map Picker, manual stop path, saving and reopening, RowVersion and strong If-Match, invitations, and durable Start/Finish recovery continue through their existing entry points.

## Shared Android connectivity

The Android main manifest grants Internet access. Flutter reads the origin from the `WAYHUNTER_API_BASE_URL` build define. The validated origin is HTTPS and requests use the platform certificate trust chain with redirects disabled. Protected requests attach a Bearer token and the transport times out after 15 seconds. Encrypted local credentials are scoped by environment and API URI. Bootstrap matches the restored account against `/identity/me`; logout attempts revocation and clears local storage. A current protected 401 closes the shell and discards the stored credential. A stale 401 cannot expire the replacement session, and a resource 403 stays scoped to that resource.

Registration, OTP verification, login, and recovery routes exist. The OTP 429 server retry header still has no mobile binding, so Flutter uses its local resend cooldown. Timeout, network, 5xx and malformed responses have separate client error kinds. Existing screens offer safe read retries and retain ambiguous write state where appropriate. Mobile session renewal has no verified refresh endpoint.

## Backend endpoint verification matrix

Routes listed under **Mobile** use the exact `/api/mobile` prefix. All private Mobile routes below require the authenticated caller unless identified as public. Bracket notation means separate collection and item routes where shown.

| Scope | Method and route | Source-verified contract and current Flutter status |
| --- | --- | --- |
| Health, public | `GET /health` | Returns `HealthResponse` with service, status and UTC timestamp. Process liveness only. |
| M1, public | Mobile `POST /identity/register`, `POST /identity/resend-otp`, `POST /identity/verify-otp`, `POST /identity/login` | Register 201, resend 202 or 429 with Retry-After, verify 204, login returns user ID, access token and expiry. Resend delivery requires the email provider. |
| M1 | Mobile `GET/PUT /identity/me`, `POST /auth/logout` | Owner-bound private profile, narrow display-name and bio update, and authenticated revocation. |
| M2 Traveller | Mobile `POST/GET /trip-plans`, `GET/PUT/DELETE /trip-plans/{tripPlanId}` | `CreateTripPlanDto` and `TripPlanResponseDto` preserve stop order, coordinates and optional place ID. Trip edits send `expectedRowVersion`. |
| M2 saved stops | Mobile `POST /trip-plans/{tripPlanId}/stops`, `PUT /trip-plans/{tripPlanId}/stops/order`, `DELETE /trip-plans/{tripPlanId}/stops/{stopId}` | Existing stop editing sends the current version where available. Remove uses strong `If-Match` for a versioned plan. |
| M2 Route Review | Mobile `POST /trip-plans/routes/preview` | New binding to `RoutePreviewRequest.orderedStops`. 200 carries validated geometry, distance, duration, provider, nullable encoded polyline and `trafficAware: false`. 400 rejects invalid input, 429 is per-account quota, 502 is invalid provider data, 503 is unavailable provider. |
| M3 invitations | Mobile `POST /trips/{tripPlanId}/invitations`, `GET /trip-invitations/pending`, `POST /trip-invitations/{invitationId}/{accept,reject,cancel}`, `DELETE /trips/{tripPlanId}/members/{memberUserId}` | Existing owner/recipient flow. The server checks eligibility and current membership. Acceptance is independent of GPS consent. |
| M3 consent | Mobile `PUT /trips/{tripPlanId}/sessions/{sessionId}/gps-consent`, SignalR `/hubs/trip-location` | `SetMyTripGpsConsentRequest.isGranted` targets the eligible active member from authentication. **DECISION_REQUIRED** for a member-facing consent status/navigation contract and live location integration. |
| M3 sessions | Mobile `POST /trips/{tripPlanId}/sessions`, `POST /trips/{tripPlanId}/sessions/{sessionId}/{pause,resume,finish}`, `GET /trips/{tripPlanId}/sessions/{sessionId}/recover` | Existing owner controls and encrypted operation markers. Recovery reads Active/Paused with a known ID. 404 on Finish recovery does not establish completion. Lost Start without an authorized ID and authoritative terminal recovery remain **BLOCKED**. |
| M3 safety | Mobile `POST /trips/{tripPlanId}/sessions/{sessionId}/im-safe`, `GET /trips/{tripPlanId}/hazards`, `POST /trips/{tripPlanId}/hazards` | Safe Check-in receipt is deduplicated per account/session. Warnings depend on real route geometry within 1 km, include photo capture/report time and expire 24 hours after report. Hazard reporting requires approved capture and private media. An empty warning list cannot establish provider health. |
| M3 memories | Mobile `GET/POST /trips/{tripPlanId}/memories`, `GET/DELETE /trips/{tripPlanId}/memories/{memoryId}` | Private text is connected. An uncertain save retains its operation ID and caption. Private media grant and completion require a deployed provider. |
| M4 Hunter reads | Mobile `GET /hunter/places`, `GET /hunter/submissions`, `GET /hunter/submissions/{submissionId}` | Approved-place discovery and authenticated owner history/status. A foreign or missing submission returns 404. The status response omits review reasons. |
| M4 Hunter writes | Mobile `POST /hunter/submissions`, `PUT/DELETE /hunter/submissions/{submissionId}`, `POST /hunter/submissions/{submissionId}/{capture-sessions,evidence,submit}` | Draft ownership and eligible capture-session states are checked server-side. Binding requires a verifier-issued receipt tied to owner, submission, capture session, type and trusted evidence. Runtime registers the disabled verifier. Capture mutations remain gated in Flutter. |
| M5 Game reads | Mobile `GET /games`, `GET /games/{gameId}`, `GET /games/me`, `GET /games/me/attempts` | Public discovery and detail are authenticated and expiry-filtered. Creator history retains archived rows. Owner attempt refresh uses the attempt list to read server progress. Debug DEMO screens stay visibly labeled. |
| M5 Game writes | Mobile `POST /games/{gameId}/attempts`, `POST /games/drafts`, `GET/PUT/DELETE /games/drafts/{gameId}`, `POST /games/drafts/{gameId}/submit` | Gated draft, start and resume contracts. Read-only refresh does not advance a stage. Flutter has no approved trusted player proof, finish or winner write. Backend PR #256 is outside this integration. |
| M6 Wallet | Mobile `GET /coins-wallet/me`, `GET /coins-wallet/me/transactions` with `page`, `pageSize` and optional `kind=Reward` | Owner balance and history use server ledger values and reward labels. |
| M6 vouchers | Mobile `GET /coins-wallet/vouchers/offers[/{offerId}]`, `GET /coins-wallet/vouchers/requests/{requestId}[/issued-voucher]` | Reads live eligibility and an owner’s known request/issuance. QR uses the issued server payload. Collection history and protected sample image delivery remain gaps. Create, redeem and cancel remain gated. |
| M7 Home | Mobile `GET /home`, `GET /advertisements/active?placement=HomeBanner` | Aggregate Home projection exists with active owner check. Flutter retains independent profile and banner reads. PR #16 refreshes the dedicated banner query. Server schedule, placement and status control active reads. |
| M7 Admin | `PATCH /api/admin/advertisements/{advertisementId}/status`, `POST /api/admin/advertisements/{advertisementId}/image` | Trusted Admin policy for status change and image upload. Cloudinary-backed image storage is deployment-specific. An authorized Admin UI is required for publication evidence. |
| M7 Leaderboards | No verified mobile ranking route on `develop` | Official ranking views display unavailable. Debug previews are explicitly labeled and supply synthetic ranks. **DECISION_REQUIRED** for authenticated DTOs, scopes and routes. |

## Authorized staging checklist

1. **Authorization gate.** Obtain the backend owner's approved non-production HTTPS origin and deployed commit, and two authorized staging accounts. Assign A a pre-existing owned trip and B separate private records and, where appropriate, an existing invitation. Obtain a ready physical Android device and permission for credential issuance and logout revocation on these accounts. Specify separately which trip edits, invitation changes, Safe Check-in, Memories, OTP sends, fault-harness cases and Admin banner actions QA may perform. Confirm consent, trusted media, Game writes and voucher mutations stay gated for this run.
2. **Health and dependencies.** Verify the hostname and certificate chain are trusted by the device. From an approved client, verify `GET /health` returns HTTP 200, service `Wayhunter.Api`, status `ok`, and a current UTC timestamp. Ask the backend operator to confirm the feature configuration and backing stores listed below. Record dependency readiness separately from liveness. Test each read from Flutter to prove device reachability. Keep the upstream HTTP listener private if an authorized HTTPS proxy is used.
3. **Select and install on physical Android.** Enable USB debugging locally, authorize the workstation on the device, and select the physical device reporting `device` in `adb devices -l`. Identify it by local model and connection and use its serial only in local commands. Android debug Maps reads the restricted SDK key from ignored `android/maps.local.properties`; the server-side Routes credential stays on the backend. Verify the key is provisioned for the Android application and signing identity without printing it.

   ```powershell
   adb devices -l
   $wayhunterDevice = Read-Host 'Authorized physical Android device ID'
   $wayhunterOrigin = (Read-Host 'Authorized HTTPS staging origin, without /api').TrimEnd('/')
   if ($wayhunterOrigin -notmatch '^https://[^/?#@]+$') { throw 'A trusted HTTPS origin is required.' }
   adb -s $wayhunterDevice get-state
   Invoke-RestMethod -Uri "$wayhunterOrigin/health" | Select-Object service,status,timestampUtc
   flutter build apk --debug --dart-define=WAYHUNTER_ENV=staging "--dart-define=WAYHUNTER_API_BASE_URL=$wayhunterOrigin"
   if ($LASTEXITCODE -ne 0) { throw 'Staging APK build failed.' }
   adb -s $wayhunterDevice install -r build/app/outputs/flutter-apk/app-debug.apk
   ```

   Open Wayhunter from the device launcher. For interactive development, the equivalent entry point is `flutter run -d $wayhunterDevice --dart-define=WAYHUNTER_ENV=staging "--dart-define=WAYHUNTER_API_BASE_URL=$wayhunterOrigin"`. Enter test credentials in the app.
4. **Authentication and recovery.** With the authorized accounts, sign in as A, force-stop and reopen from the launcher, verify A’s restored profile, then sign out and sign in as B. Confirm A’s content disappears. For approved auth cases, use a server-expired or revoked test session to confirm 401 handling and a pre-existing denied resource to confirm 403 isolation. Test transient network loss on a read and retry after reconnecting. On a separate explicit approval, test registration, OTP verification, throttling and delivery with a designated inbox.
5. **Person 1.** Start with pre-existing owned trips, read invitation inbox, route warnings, and private Memories. Use an approved Routes quota for Route Review. With separately approved writes, create a disposable trip, add and confirm two pins through the picker, save, reopen, edit, reorder, and review. Exercise a stale version through two authorized clients. For invitations, use the designated temporary trip and recipient. Follow the session lifecycle only on an approved fixture and use an approved staging fault harness for uncertain responses. Inspect server status before retrying, and keep lost Start and terminal Finish cases blocked where the server cannot reconcile them. Check Safe Check-in receipts and private text Memory replay only on the designated trip.
6. **Person 2 and M7.** Compare A and B’s authenticated Hunter, Game attempts, My Games, Wallet, reward and issued-voucher views. Use pre-existing test request IDs for voucher lookup. Keep debug DEMO results separate from staging. Check the existing live Home banner and its return/refresh behavior. Only an authorized Admin may publish and pause a designated staging banner for the publication check. Record official Leaderboard unavailable while its contract remains absent.
7. **Evidence and results.** Record UTC time, Flutter commit, deployed backend commit, device model/Android version, account alias, HTTP method and route template, expected status, observed status, screen result and a redacted correlation ID where available. Never include credentials, Bearer headers, OTP values, voucher QR/code, exact coordinates or personal payloads. Mark **PASS** only with a matching physical-device result, **FAIL** when an authorized run differs, or **BLOCKED** with the missing prerequisite. Use the actual columns below for the authorized run.

## Live E2E result matrix

All rows begin at **BLOCKED**. **Actual** records the observed live result only.

| Flow | Expected staging result | Actual | Result and blocker |
| --- | --- | --- | --- |
| Health and physical Android reachability | Liveness 200 and verified TLS on device requests | Unobserved | **BLOCKED** · HTTPS origin and physical device |
| Registration and OTP | Register 201, verify 204, resend 202 or throttled 429 | Unobserved | **BLOCKED** · inbox, mail provider and approval |
| Login, Bearer and restore | Login and owner `/me` 200, correct restored profile | Unobserved | **BLOCKED** · authorized accounts and staging |
| Logout, 401/403 and account switch | Revocation/clear, 401 gates access, 403 remains scoped, no previous owner data | Unobserved | **BLOCKED** · account pair and auth fixtures |
| Timeout, network recovery and server errors | Read error surfaced, manual retry succeeds after recovery, no automatic write replay | Unobserved | **BLOCKED** · staging and approved fault harness |
| Traveller existing trip reopen | Server stop coordinates and order displayed | Unobserved | **BLOCKED** · M2 persistence and owned fixture |
| Map Picker and approved trip writes | Permission denial permits manual stops; confirmed pins survive save/reopen; stale version is rejected | Unobserved | **BLOCKED** · Android Maps, M2 SQL and write approval |
| Route Review | Ordered pinned stops yield 200 estimates, missing provider surfaces unavailable | Unobserved | **BLOCKED** · Routes provider and authorized quota |
| Invitation decisions and GPS consent | A/B see their own permitted decisions, acceptance is separate from consent | Unobserved | **BLOCKED** · membership fixture, write approval and member consent read flow |
| Live trip and uncertain actions | Valid transitions, encrypted marker survives restart, unresolved or foreign recovery stays blocked | Unobserved | **BLOCKED** · SQL, write/fault approval and authoritative lost Start/terminal Finish contracts |
| Safe Check-in | 200 receipt with same logical check-in on approved replay | Unobserved | **BLOCKED** · M3 SQL, check-in flag and approved session |
| Hazard warning | Server returns only route-matched, active warnings with capture time | Unobserved | **BLOCKED** · Routes, M3 SQL and test geometry/fixtures |
| Trip Memories | Private list/detail only for permitted owner, same operation ID on approved retry | Unobserved | **BLOCKED** · memory SQL, fixtures and write approval |
| Hunter Places and history | Approved discovery, owned statuses, 404 for foreign submission | Unobserved | **BLOCKED** · shared auth, Hunter SQL and owner fixtures |
| Hunter capture | Approved owned Draft and provider-verified live evidence required | Unobserved | **BLOCKED** · trusted location, private receipt verifier and approval |
| Game discovery, history and attempt refresh | 200 for eligible reads, archived creator rows retained, progress owner-scoped | Unobserved | **BLOCKED** · Games SQL, fixtures and archive worker |
| Wallet history and issued voucher | Owner ledger and protected issuance data, foreign voucher request denied | Unobserved | **BLOCKED** · Wallet storage, voucher runtime and fixture IDs |
| Home banner refresh and Admin publication | Active banner appears, pause removes it through PR #16 refresh | Unobserved | **BLOCKED** · Ads storage, provider and authorized Admin |
| Official Leaderboard | Authenticated per-module rankings | Unobserved | **BLOCKED** · mobile ranking contract |

## Remaining dependencies and release blockers

- M1 shared authentication needs `Identity:EnableSharedAuthentication`, trusted session identity and deployed storage. Resend needs authorized email delivery. No staging HTTPS origin, account pair or attached physical Android device was available.
- M2 requires `TravelPlanning:EnableSqlPersistence` for durable trips, Android Maps SDK configuration for live picker tiles, and `TravelPlanning:Maps:EnableRoutes` with a server-side Routes credential. M3 requires `TripSafety:EnableSqlPersistence` and actual invitation eligibility. Check `TripSafety:EnableSafeCheckIn`, `TripSafety:EnableSqlTripMemories`, routes for hazard matching, and deployed notification/media dependencies for their full workflows. Verify any hazard expiry worker separately.
- Trip recovery still needs an authoritative plan-scoped lookup for a lost Start and terminal status for an uncertain Finish. Joining a trip grants membership, while a member-facing GPS consent read flow and live subscription integration remain open.
- M4 status reads require shared SQL, and trusted location/media receipt issuance and verification block capture. M5 reads require `Games:EnableSqlPersistence` and persistent archive needs `Games:EnableExpiryWorker`. Attempt writes are gated by Development, Games SQL and `Games:EnableSqlAttemptWriter`. Draft registration is separately gated. Player proof, finish and winner contracts still need review.
- M6 uses deployed wallet/ledger storage and `CoinsWallet:EnableSqlVoucherRuntime` for vouchers. M7 uses `Advertisements:EnableSqlPersistence` and configured image storage. Official ranking routes are absent. Android release signing still points to the debug signing configuration in `android/app/build.gradle.kts`; release distribution needs its own reviewed signing and Maps configuration.

## Changed files

- `lib/features/traveller/planning/data/trip_plans_api.dart`
- `lib/features/traveller/planning/domain/trip_route_preview.dart`
- `lib/features/traveller/planning/presentation/traveller_screens.dart`
- `lib/features/traveller/planning/presentation/trip_route_review.dart`
- `test/person1/trip_planning_test.dart`
- `docs/integration/MOBILE_BACKEND_INTEGRATION_BATCH_4.md`

## Local validation

| Command | Result |
| --- | --- |
| `dart format` on changed Dart files | Passed on all five files |
| `flutter analyze` | Passed with no issues |
| `flutter test --reporter expanded` | All 268 tests passed. Four new mocked tests cover ordered pins and retry, missing pins and quota, malformed requests/responses, and session replacement. |
| `flutter build apk --debug` | Passed. Output at `build/app/outputs/flutter-apk/app-debug.apk`. |
| `git diff --check` | Passed |
| `git status -sb` | Six uncommitted Batch 4 files on `feature/mobile-final-e2e-integration`, ready for human review |

## Next recommended tasks

First approve and run the two-account physical-Android checklist on a deployed HTTPS revision, recording observations against the live matrix. Prioritize M3 authoritative recovery and consent contracts next. Coordinate Hunter media, Game writes, voucher fulfillment and M7 ranking/publication review as separately authorized work.
