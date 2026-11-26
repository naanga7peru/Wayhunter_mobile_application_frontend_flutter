# Wayhunter Android E2E readiness · Batch 5

The Flutter working tree started clean on `feature/mobile-android-e2e-batch5` at `0d06b7b`, the merged PR #20 commit. GitHub confirmed that this commit matches `devlop`. Backend `develop` was `c8b3aa60eed28da4d7a78039ca1e4a5607c3921c`. The comparison with the Batch 4 backend revision showed only API project configuration for .NET User Secrets. The controllers, DTOs and feature-gate logic reviewed in Batches 1–4 are identical. **SOURCE** means BRD or owner requirements. **CODE_VERIFIED** means inspected source at the compared revisions. **BLOCKED** marks an unavailable environment, contract, dependency or approval. **DECISION_REQUIRED** marks remaining contract work. [Backend revision](https://github.com/naanga7peru/Wayhunter_mobile_application_Backend/commit/c8b3aa60eed28da4d7a78039ca1e4a5607c3921c) · [Active Rules](../second-brain/ACTIVE_RULES.md) · [Batch 1](MOBILE_BACKEND_INTEGRATION_BATCH_1.md) · [Batch 2](MOBILE_BACKEND_INTEGRATION_BATCH_2.md) · [Batch 3](MOBILE_BACKEND_INTEGRATION_BATCH_3.md) · [Batch 4](MOBILE_BACKEND_INTEGRATION_BATCH_4.md)

## Completed frontend work

OTP resend uses the positive integer seconds in the server's HTTP 429 `Retry-After` header. The existing 60-second cooldown remains the fallback for missing or invalid values and the normal interval after HTTP 202. Resend requires the documented 202 before showing the requested-message confirmation. The countdown sends no request when it reaches zero. The user can explicitly retry. Transport forwards only this response header for delay parsing, and exception text stays free of headers, response bodies and credentials. [Identity controller](https://github.com/naanga7peru/Wayhunter_mobile_application_Backend/blob/c8b3aa60eed28da4d7a78039ca1e4a5607c3921c/src/Wayhunter.Api/Controllers/Mobile/IdentitySocial/IdentityAuthenticationController.cs) · [OTP service](https://github.com/naanga7peru/Wayhunter_mobile_application_Backend/blob/c8b3aa60eed28da4d7a78039ca1e4a5607c3921c/src/Wayhunter.Api/Services/IdentitySocial/IdentityRegistrationOtpService.cs)

- **Person 1.** The source audit covers registration, login and account restore, profile, ordered trip plans and Route Review, invitations, trip sessions, Safe Check-in, hazards and Memories. Backend GPS consent has a member-scoped setter. Member navigation, consent reads and authoritative recovery for lost Start or uncertain terminal Finish remain open.
- **Person 2.** Hunter discovery and owner submission history, Game discovery and owner history/attempt refresh, and Wallet and voucher status are backend-connected reads. Debug Game and ranking previews are DEMO. Hunter capture, Game writes and voucher mutations remain gated.
- **M7.** Mobile uses the PR #16 active HomeBanner refresh. Publication requires the separate authorized Admin API. Official leaderboard remains unavailable pending an authenticated contract.

## Android preflight

| Check | Observed evidence | Result |
| --- | --- | --- |
| Expected Flutter base | `HEAD`, local `origin/devlop` and the GitHub comparison agree on PR #20 | **PASS** · repo preflight |
| Android networking | Main manifest grants Internet, fine and coarse location. Bootstrap uses `WAYHUNTER_API_BASE_URL` and validates HTTPS. Platform trust remains enabled. Redirect following is disabled and shared transport times out after 15 seconds. | **PASS** · source inspection |
| Credentials and session isolation | Android encrypted storage keys are scoped by environment and API URI, and app backup is off. Restore uses owner-matched `/me`, logout clears local credentials, and a current protected 401 expires the session. Obsolete responses and a stale 401 cannot restore or expire the replacement session. Resource-level 403 keeps the shell. | **PASS** · source and mock coverage |
| GPS and Map Picker | Geolocator distinguishes denied/permanently denied permission, services off, and read timeout. The picker keeps an existing confirmed pin if GPS fails and has a manual-stop path. Android Maps SDK support and the configuration probe are debug-only. An ignored local debug config file had a nonblank Maps key entry. | **PASS** · local configuration and source check. **BLOCKED** · physical GPS, key restriction and tile verification |
| Physical Android inventory | Installed SDK's `adb devices -l` returned zero devices. Only counts were recorded. | **BLOCKED** · no attached Android device |
| Approved staging origin and test accounts | No authorized HTTPS origin or account pair was supplied. The origin environment variable was absent. No live health probe, login or feature request ran. | **BLOCKED** · staging authorization and inputs |

Current Android dependencies are the repo's existing `http`, `flutter_secure_storage`, `geolocator` and `google_maps_flutter`. No package or Android manifest changes were needed for the OTP fix.

## Verified endpoint matrix

All shortened mobile paths start with `/api/mobile`. The server resolves private ownership from the authenticated actor. The full endpoint audit and payload references are in [Batch 4](MOBILE_BACKEND_INTEGRATION_BATCH_4.md#backend-endpoint-verification-matrix).

| Module | Method and path | Flutter and contract status |
| --- | --- | --- |
| Health | `GET /health` | Public liveness response with service, status and UTC timestamp. It does not probe backing services. |
| M1 identity | `POST /identity/register`, `POST /identity/verify-otp`, `POST /identity/resend-otp`, `POST /identity/login` | Public registration 201, verification 204, resend 202 or throttled 429, login returns owner token and expiry. Batch 5 binds resend cooldown. Live email requires configured delivery. |
| M1 profile/session | `GET/PUT /identity/me`, `POST /auth/logout` | Connected owner profile, display-name/bio editing, startup ownership check and logout. No verified mobile refresh endpoint. |
| M2 trips and stops | `POST/GET /trip-plans`, `GET/PUT/DELETE /trip-plans/{tripPlanId}`, `POST /trip-plans/{tripPlanId}/stops`, `PUT /trip-plans/{tripPlanId}/stops/order`, `DELETE /trip-plans/{tripPlanId}/stops/{stopId}` | Connected owner creation, ordered saved coordinates, reopen and edits. Existing writes use RowVersion where supported. Stop deletion uses strong `If-Match` on versioned plans. |
| M2 Route Review | `POST /trip-plans/routes/preview` | Batch 4 uses saved ordered pins and validated distance/duration for 2–27 stops. Compute-only preview consumes provider quota. 429, 502 and 503 have visible failure states. |
| M3 invitations | `GET /trip-invitations/pending`, `POST /trips/{tripPlanId}/invitations`, `POST /trip-invitations/{invitationId}/{accept,reject,cancel}`, `DELETE /trips/{tripPlanId}/members/{memberUserId}` | Wired with owner/recipient checks. Accepting membership does not grant GPS consent. |
| M3 GPS consent | `PUT /trips/{tripPlanId}/sessions/{sessionId}/gps-consent`, SignalR `/hubs/trip-location` | Eligible accepted members can set their own consent through the server contract. **DECISION_REQUIRED** for member navigation, authoritative consent reads and approved location sharing integration. |
| M3 sessions and recovery | `POST /trips/{tripPlanId}/sessions`, `POST /trips/{tripPlanId}/sessions/{sessionId}/{pause,resume,finish}`, `GET /trips/{tripPlanId}/sessions/{sessionId}/recover` | Connected owner controls and durable owner-scoped markers for uncertain Start/Finish. Known Active/Paused can be recovered. Lost Start without a verified session ID and ambiguous terminal Finish remain blocked. Recovery 404 alone establishes neither completion nor a safe replay. |
| M3 safety | `POST /trips/{tripPlanId}/sessions/{sessionId}/im-safe`, `GET /trips/{tripPlanId}/hazards` | Safe Check-in consumes the authenticated receipt. Hazard reads use backend route matching, photo capture time and the 24-hour warning window. Hazard reporting needs approved location and private media. |
| M3 memories | `GET/POST /trips/{tripPlanId}/memories`, `GET/DELETE /trips/{tripPlanId}/memories/{memoryId}` | Private text owner flows are connected. Retry in the open form reuses the existing operation ID and caption. Private media still needs its upload provider. |
| M4 Hunter reads | `GET /hunter/places`, `GET /hunter/submissions`, `GET /hunter/submissions/{submissionId}` | Backend-integrated read-only discovery and owner status/history. Public-facing places are server-approved. Foreign submission lookup is 404. |
| M4 Hunter writes | `POST /hunter/submissions`, `PUT/DELETE /hunter/submissions/{submissionId}`, `POST /hunter/submissions/{submissionId}/{capture-sessions,evidence,submit}` | Blocked. Eligible owned Draft and trusted live evidence are required. Deployed verifier configuration and the separate camera work need review. |
| M5 Game reads | `GET /games`, `GET /games/{gameId}`, `GET /games/me`, `GET /games/me/attempts` | Backend-integrated read-only discovery, detail, creator archive, and player history/progress refresh. Refresh cannot advance stages. Synthetic previews remain labeled DEMO. |
| M5 Game writes | `POST /games/{gameId}/attempts`, `POST /games/drafts`, `GET/PUT/DELETE /games/drafts/{gameId}`, `POST /games/drafts/{gameId}/submit` | Backend gates and explicit review remain required. Trusted player proof, finish and winner workflows need available HTTP contracts. Backend M5 PR #256 is outside Batch 5. |
| M6 wallet | `GET /coins-wallet/me`, `GET /coins-wallet/me/transactions` with `page`, `pageSize` and optional `kind=Reward` | Backend-integrated owner balance, ledger and reward labels. |
| M6 vouchers | `GET /coins-wallet/vouchers/offers[/{offerId}]`, `GET /coins-wallet/vouchers/requests/{requestId}[/issued-voucher]` | Read-only owner offer, request and issued receipt. QR needs issued server data. Create, redeem and cancel stay gated. |
| M7 Home and banner | `GET /home`, `GET /advertisements/active?placement=HomeBanner` | Authenticated active-owner Home projection exists. Flutter uses independent profile/banner reads and PR #16 refresh. The server owns ad placement, active status and schedule. |
| M7 Admin | `PATCH /api/admin/advertisements/{advertisementId}/status`, `POST /api/admin/advertisements/{advertisementId}/image` | Admin-only publication and upload. Use the authorized Admin workflow. Mobile uses the authenticated active-banner read. |
| M7 rankings | No verified mobile leaderboard endpoint | Official rankings stay unavailable. Debug DEMO previews remain opt-in and labeled. |

## PowerShell and ADB staging setup

**Authorization gate.** Use an approved HTTPS staging origin and pre-provisioned accounts A and B. Obtain permission for session creation/revocation, provider quota usage and each live write scenario before running it. Have the staging owner record the deployed backend commit and provider readiness. Confirm the device trusts the origin's certificate chain. If development uses an approved HTTPS proxy, the Android connection still uses its trusted HTTPS hostname and the upstream HTTP listener stays private.

Use a physical Android device with USB debugging and local workstation authorization. Keep the serial local. The app reads the origin at build time. Use the reviewed Android debug key configuration from ignored `android/maps.local.properties`; server-side Routes and other provider keys stay on the backend. Enter account credentials interactively in the app.

```powershell
$wayhunterSdk = if ($env:ANDROID_HOME) {
  $env:ANDROID_HOME
} elseif ($env:ANDROID_SDK_ROOT) {
  $env:ANDROID_SDK_ROOT
} else {
  Join-Path $env:LOCALAPPDATA 'Android/Sdk'
}
$wayhunterAdb = Join-Path $wayhunterSdk 'platform-tools/adb.exe'
if (!(Test-Path -LiteralPath $wayhunterAdb)) { throw 'Android platform-tools are required.' }
& $wayhunterAdb devices -l
$wayhunterDevice = Read-Host 'Authorized physical Android device serial'
if ([string]::IsNullOrWhiteSpace($wayhunterDevice) -or
    ($wayhunterDevice -match '^emulator-') -or
    ((& $wayhunterAdb -s $wayhunterDevice get-state) -ne 'device')) {
  throw 'Select an authorized physical device in the device state.'
}
$wayhunterUri = [uri](Read-Host 'Authorized HTTPS staging origin, without /api')
if (!$wayhunterUri.IsAbsoluteUri -or $wayhunterUri.Scheme -ne 'https' -or
    !$wayhunterUri.Host -or $wayhunterUri.UserInfo -or $wayhunterUri.Query -or
    $wayhunterUri.Fragment -or $wayhunterUri.AbsolutePath -ne '/') {
  throw 'Enter a trusted HTTPS origin with no path, query, fragment or user info.'
}
$wayhunterOrigin = $wayhunterUri.GetLeftPart([System.UriPartial]::Authority)
$wayhunterHealth = Invoke-RestMethod -Uri "$wayhunterOrigin/health" `
  -TimeoutSec 15 -MaximumRedirection 0 -ErrorAction Stop
if ($wayhunterHealth.service -ne 'Wayhunter.Api' -or $wayhunterHealth.status -ne 'ok') {
  throw 'Staging returned an unexpected liveness response.'
}
$wayhunterHealth | Select-Object service, status, timestampUtc
flutter build apk --debug --dart-define=WAYHUNTER_ENV=staging "--dart-define=WAYHUNTER_API_BASE_URL=$wayhunterOrigin"
if ($LASTEXITCODE -ne 0) { throw 'Staging apk build failed.' }
& $wayhunterAdb -s $wayhunterDevice install -r build/app/outputs/flutter-apk/app-debug.apk
if ($LASTEXITCODE -ne 0) { throw 'Staging apk installation failed.' }
& $wayhunterAdb -s $wayhunterDevice shell am start -n 'lk.wayhunter.wayhunter_mobile/.MainActivity'
```

Expected health is HTTP 200, `service=Wayhunter.Api` and `status=ok`. The workstation health request does not establish device TLS or provider availability. Use app outcomes and the staging operator's deployment checks for those conditions.

## Two-account staging plan and observed live results

Give A a pre-existing owned trip, private Memory, Hunter history, Game attempt and Wallet fixtures. Give B independent owner history and an eligible invitation fixture. Keep sensitive test details in the approved environment. Run the reads first. For any approved write, use a disposable staging fixture and a separate permission record. Record expected and actual status, UTC observation time, build rev, deployed rev, device model/Android version, account alias, method and route template, visible outcome, and redacted correlation ID. Omit credentials, headers, OTP and voucher values, exact GPS coordinates, recipient identities and payload contents.

| Flow | Expected on authorized physical Android | Actual live evidence | Live result |
| --- | --- | --- | --- |
| HTTPS and liveness | Health 200 and successful physical device TLS | No device or staging origin | **BLOCKED** |
| Sign-in, restore, logout and account switch | A authenticates and restores after force-stop/reopen. Sign out revokes/clears. B signs in and sees B's data only. A stale response is discarded. | Unobserved | **BLOCKED** · authorized accounts and device |
| OTP, registration and throttle | An approved test inbox receives registration/resent mail. Verify returns 204. A legitimate throttle fixture returns 429 and displayed delay follows Retry-After; a successful resend is 202. | Unobserved | **BLOCKED** · delivery and fixture authorization |
| Current 401, resource 403 and network error | Revoked/expired test session signs out, denied resource retains session, transient read can be retried after reconnecting | Unobserved | **BLOCKED** · sanctioned auth / fault fixtures |
| Profile and saved Traveller reads | A reopens the existing plan with ordered pins. B sees B's profile/plans and cannot see A's private data. Approved Route Review produces server estimates. | Unobserved | **BLOCKED** · staging M2 SQL and Routes quota |
| GPS and approved Traveller writes | Deny / allow while in use / disable services paths work. Save new pins, reopen, edit and reorder a disposable trip. A stale client must reload and respect RowVersion / If-Match. Profile changes require approval. | Unobserved | **BLOCKED** · phone, Maps SDK and write approval |
| Invitation and independent consent | A/B only see permitted decisions on an approved trip. Membership alone causes no GPS publication. | Unobserved | **BLOCKED** · eligible fixtures and consent navigation/read contract |
| Session transitions and recovery | Approved Start, Pause, Resume and Finish reflect returned state. Approved fault harness confirms marker behavior, known active recovery, and no POST replay on unresolved outcomes. | Unobserved | **BLOCKED** · M3 runtime and authoritative lost Start/terminal Finish contracts |
| Safe Check-in, hazards and private Memories | Approved Check-in returns same logical receipt on repeat. Only active route-matched hazards display. Owner-only text Memories and same-operation replay match backend receipts. | Unobserved | **BLOCKED** · M3 storage, provider, fixtures and write approval |
| Hunter | Approved discovery plus A/B scoped status/history. Foreign status yields safe 404; capture is gated. | Unobserved | **BLOCKED** · authoritative storage, fixtures and trusted evidence provider |
| Games | Read discovery, current detail, archives and attempt refresh. B never sees A's attempts. Archived games stay out of discovery and DEMO stays labeled. | Unobserved | **BLOCKED** · Games SQL and fixture/worker readiness |
| Wallet and vouchers | Read balances/reward history and a pre-existing owner voucher. B cannot open A's voucher; issued values remain protected. | Unobserved | **BLOCKED** · Wallet storage and authorized fixtures |
| Home, Admin publication and Leaderboard | Refresh existing HomeBanner. A separate authorized Admin publishes/pauses a test banner and mobile reflects it. Official ranking view stays unavailable pending the contract. | Unobserved | **BLOCKED** · publication permissions, storage/provider and ranking contract |

Use **PASS** for an observed match, **FAIL** for a mismatch on an authorized run, and **BLOCKED** for a missing prerequisite. No live flow has a PASS or FAIL in this checkout.

## Outstanding dependencies and release blockers

- Stage a trusted HTTPS deployment, account pair and physical Android device. Have the operator confirm `Identity:EnableSharedAuthentication`, runtime identity/session storage and email delivery. Verify session expiry and isolation on the device.
- Verify M2 `TravelPlanning:EnableSqlPersistence` and `TravelPlanning:Maps:EnableRoutes` with configured server-side Routes, and M3 `TripSafety:EnableSqlPersistence`, invitation eligibility, `TripSafety:EnableSafeCheckIn` and `TripSafety:EnableSqlTripMemories`. Lost Start, terminal Finish, and member GPS consent still need authoritative contracts. Hazard evidence and Memory media need approved private media.
- Verify Hunter SQL and trusted receipt/location integration. Games reads use `Games:EnableSqlPersistence`; archive uses `Games:EnableExpiryWorker`. Development attempt writes additionally use `Games:EnableSqlAttemptWriter`, and draft registration is separately gated. Game write approval and player proof/finish contracts remain outstanding.
- Verify owner Wallet storage and `CoinsWallet:EnableSqlVoucherRuntime`. Voucher request collection history and protected sample image delivery remain gaps. Verify `Advertisements:EnableSqlPersistence`, configured ad image storage and authorized staging Admin. Official mobile leaderboard contracts are absent.
- Android release Maps is currently unavailable through the debug-only provider, and release signing points to the debug configuration. Review release signing and Android Maps key provisioning separately before distribution.

## Changed files

- `lib/core/network/api_client.dart`
- `lib/core/network/package_http_transport.dart`
- `lib/features/auth/data/identity_api.dart`
- `lib/features/auth/presentation/views/otp_verification_screen.dart`
- `test/foundation/api_client_test.dart`
- `test/person1/auth_flow_test.dart`
- `test/widget/M1/otp_verification_screen_test.dart`
- `docs/integration/MOBILE_ANDROID_E2E_BATCH_5.md`

## Local validation

| Check | Result |
| --- | --- |
| `dart format` | Ran on the changed Dart files. The legacy OTP widget test keeps its existing layout with one assertion updated. |
| `flutter analyze` | **PASS** · exit 0. No issues found. |
| `flutter test --reporter expanded` | **PASS** · exit 0. All 270 tests passed on the final diff. Batch 5 uses mocked HTTP responses for numeric and invalid `Retry-After`, HTTP 202 validation, and the manual resend countdown. |
| `flutter build apk --debug` | **PASS** · exit 0. Built `build/app/outputs/flutter-apk/app-debug.apk` without a staging origin. Gradle emitted a Java native-access warning. |
| `git diff --check` | **PASS** · clean whitespace check. |
| `git status -sb` | Eight uncommitted Batch 5 files on `feature/mobile-android-e2e-batch5`, at `0d06b7b`, ready for human review. |
| Staging PowerShell block | **PASS** · parsed locally. Live execution remains **BLOCKED**. |

## Next authorized work

Confirm the staging deployment and provider flags, supply the two authorized test accounts through the approved channel, and connect a physical Android device. Run the read and isolation scenarios before any approved write. Record the device observations in the live matrix. Use the unresolved recovery, consent and provider dependencies to scope follow-up work after that run.
