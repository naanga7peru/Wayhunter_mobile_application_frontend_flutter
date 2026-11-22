# WayHunter — Mobile, Admin & Backend Integration Handoff

**Version:** 0.1 — Proposed team integration baseline
**Date:** 2026-11-22
**Audience:** Flutter Person 1, Flutter Person 2, Angular Admin developers, ASP.NET Core backend owners, QA and Codex sessions.
**Purpose:** Enable independent development, then integrate the applications through the same backend without rewriting feature UIs or inventing API contracts.

> READ THIS FIRST: This file describes the agreed planning direction and the inspected source-level API inventory. It is not a replacement for approved SecondBrain decisions, actual request/response DTOs or runtime test evidence. Unconfirmed items must be resolved with their backend owner before live integration. The two-person mobile allocation is a delivery split, not a change to the original seven-member domain ownership.

## 1. Architecture and non-negotiable rules

``` text
Flutter Mobile (Person 1 + Person 2)       Angular Admin (separate team)
              |                                          |
              | /api/mobile/...                          | /api/admin/...
              +------------------+-----------------------+
                                 |
                         ASP.NET Core API
                    Authentication / Authorization
                  Domain rules / Workflows / Events
                                 |
                            SQL Server
                     Authoritative persisted state
```

- Flutter must not call Angular directly. Angular must not call Flutter directly. Neither frontend accesses SQL Server directly.
- Both applications use the same environment's API and records. Keep the API base URL environment-configurable; do not hardcode local machine addresses or secrets.
- Admin authentication and RBAC are enforced by the backend on every protected action. Hiding a button is not authorization. A mobile user token must never grant Admin permissions.
- Backend owns business states, validated coordinates, timestamps, approval decisions, coin balances, rewards, redemption holds, voucher issuance and audit records.
- Server-created entity IDs are used across both apps. Do not match records by display name, email text, list position or local mock ID.
- Persist the domain change before notifying users. Backend-controlled outbox/retry or equivalent approved mechanism must not duplicate financial rewards or notifications.
- Mobile refreshes the relevant detail, inbox and wallet after mutations, on screen re-entry, and when an applicable notification arrives. Do not assume a websocket or push transport is available. First support authorized reads and user-visible refresh/retry.
- Protect access tokens, private evidence, precise GPS, contact information and voucher codes. Do not log them or include live sensitive data in fixtures.
- Admin decisions require server-side validation, actor identity, timestamp and reason where applicable. Concurrency, retry and duplicate actions must be safe.
- Use only Coins. Do not bring back legacy HP/RC/XP balances or fabricate financial, verification, mapping or ranking results.

## 2. Repositories and source of truth

| Repository                                                                                                      | Working reference                                                      |
|-----------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------|
| [SecondBrain documentation](https://github.com/naanga7peru/Wayhunter_SecondBrain_Docs)                          | Latest approved rules and decisions; confirm current branch with owner |
| [ASP.NET Core backend](https://github.com/naanga7peru/Wayhunter_mobile_application_Backend/tree/develop)        | `develop` inspected snapshot                                           |
| [Flutter mobile](https://github.com/naanga7peru/Wayhunter_mobile_application_frontend_flutter/tree/devlop)      | `devlop` (actual branch spelling)                                      |
| [Angular Admin](https://github.com/naanga7peru/Wayhunter_mobile_application_admindashboard_angular/tree/devlop) | `devlop` (actual branch spelling)                                      |

Read each repository's `AGENTS.md` and active guidance before editing. In SecondBrain, locate `Wayhunter_Second_Brain_v1_0/knowledge/` and read `LATEST_APPROVED_2026-11-11.md`, `PROJECT_RULES.md`, `SOURCE_OF_TRUTH.md`, `WORKFLOWS.md`, `ADMIN_17_MODULES.md`, `API_CONTRACTS_STATUS.md`, `DECISIONS_PENDING.md`, `TEAM_GIT_WORKFLOW.md`, and `TEST_AND_ACCEPTANCE.md`. Review member-specific scope and the cross-module contracts. Check for newer approved decisions before implementation.

Use these evidence labels throughout implementation reports:

| Label             | Meaning                                                                                |
|-------------------|----------------------------------------------------------------------------------------|
| APPROVED_RULE     | Supported by approved project documentation                                            |
| CODE_VERIFIED     | Route, DTO or behavior found in inspected source; not proof of runtime readiness       |
| RUNTIME_VERIFIED  | Actual executed test with environment, branch/commit, result and reproducible evidence |
| PROPOSED          | Design or semantic contract awaiting agreement                                         |
| DECISION_REQUIRED | Missing, conflicting or not yet confirmed rule/API                                     |

If an older prototype conflicts with approved business rules, follow the approved rules. If docs and code disagree, report the discrepancy and request owner resolution; do not silently change either.

## 3. Team ownership and independent development

| Team               | Delivery scope                                                                                                            |
|--------------------|---------------------------------------------------------------------------------------------------------------------------|
| Mobile Person 1    | Authentication, Home/Ads, Traveller planning, active trip, hazards/safety, friend flows, profile, settings, notifications |
| Mobile Person 2    | Hunter, game creation, game playing, wallet, vouchers/redemption, shared leaderboard                                      |
| Angular Admin team | Admin auth/RBAC and the 17 Admin modules; queue/list/detail/review/action UI                                              |
| Backend M1         | Identity/Social: identity, profile, friend eligibility, roles and user policy                                             |
| Backend M2         | TravelPlanning: plans, place picking, routes, suggested/AI plans                                                          |
| Backend M3         | TripSafety: sessions, hazards, group invitations, GPS consent, memories, notifications                                    |
| Backend M4         | HunterPlaces: evidence, review, approved place publication                                                                |
| Backend M5         | Games: creation, proof, attempts, winner, expiry and ranking contracts                                                    |
| Backend M6         | CoinsWallet: ledger, rewards, holds, voucher offer/inventory/redemption/issuance                                          |
| Backend M7         | HomeAdsAnalytics: ads, campaigns, analytics                                                                               |

### Mobile common foundation (build once)

Bootstrap/environment, app router and typed route arguments, app shell and bottom navigation, common theme/widgets, API client, token/session management, secure storage, error/loading/empty states, permissions, location/maps interfaces, camera/media/upload interfaces, shared references and status mapping, assets/localization, test/mock setup.

Keep features isolated from each other's implementation files. Use named routes, read-only repository interfaces and shared reference types. Assign one owner per shared file; merge reviewed foundation before independent feature branches. Existing Flutter skeleton must be preserved. Proposed screen counts (41 + 43) are planning entries, not validated unique routes.

Cross-person mobile connections: Home → Hunter/Game; Profile → Wallet/My Games/My Hunts; Traveller → shared leaderboard with module; Hunter approved place → Traveller with place reference; leaderboard → other user profile with user ID; notification → authorized feature detail with entity ID. Profile activity tabs use read-only activity contracts rather than importing another developer's screen.

### Angular common foundation

Reuse existing Admin shell/routes and HTTP client. Add reviewed real Admin authentication, session gating and RBAC, API base configuration, shared queue/table/filter/pagination components, explicit loading/empty/error views, protected media preview, confirmation/reason dialogs and audit views. Do not use a development preview guard as production authorization. Keep each Admin module independently owned; do not duplicate business rules in Angular.

## 4. Mobile to Admin module matrix

| Admin module                     | Mobile connection                         | Admin responsibility                                         | Backend domain / integration note                     |
|----------------------------------|-------------------------------------------|--------------------------------------------------------------|-------------------------------------------------------|
| ADM-01 Admin Authentication      | Identity/login policy                     | Admin login, role/session state                              | M1; exact Admin auth contract not confirmed           |
| ADM-02 Dashboard                 | All modules                               | Verified summary counts and quick actions                    | M7; counts must come from real API                    |
| ADM-03 User Management           | Profile/account/friends                   | User search, warn/suspend/reactivate                         | M1; server-enforced restrictions                      |
| ADM-04 Hunter Verification       | Person 2: Add Place/My Hunts              | Review evidence, approve/reject/hold where supported         | M4; HTTP contract pending verification                |
| ADM-05 Advertisements            | Person 1: Home banner                     | Ad CRUD, schedule/status, image                              | M7; paired routes present                             |
| ADM-06 Places Management         | Hunter discoveries/Traveller place picker | Manage approved places (edit/merge/hide according to policy) | M4 + M2; read/admin contract pending                  |
| ADM-07 Trips & Historical Routes | My Plans/Trip Summary/Reuse               | Historical route review and eligible reuse                   | M2; suggested copy currently not confirmed working    |
| ADM-08 Hazard Management         | Person 1: road alerts/report hazard       | Verify/resolve/flag under policy                             | M3; some actions present; list/flag contract pending  |
| ADM-09 Group Trip Management     | Active trip/group invitations/consent     | Authorized group safety audit                                | M3; session read route present; no GPS consent bypass |
| ADM-10 Game Management           | Person 2: create/play/My Games            | Separate creation and winner review queues                   | M5; HTTP contract pending verification                |
| ADM-11 Coins & Rewards           | Wallet/Profile/Rewards                    | Ledger, rule versions, reconciliation and audit              | M6; some Admin ledger/report routes present           |
| ADM-12 Voucher Inventory         | Voucher offers                            | Offers/inventory management                                  | M6; some routes present                               |
| ADM-13 Redemptions               | My Requests/My Vouchers                   | Approve/reject/issue; controlled use/expiry                  | M6; paired action/detail routes present               |
| ADM-14 Campaign Management       | Home/sponsored content                    | Eligibility, scheduling and budgets                          | M7; full contract not confirmed                       |
| ADM-15 Reports & Analytics       | Mobile activity                           | Reports and aggregate analytics                              | M7; full contract not confirmed                       |
| ADM-16 Notifications             | Person 1: inbox/preferences               | Preview/send/schedule/cancel/summary                         | M3; some paired routes present                        |
| ADM-17 Settings & Security       | Policy-affected app actions               | RBAC, restrictions, audit and system settings                | M1/security and domain owners; exact APIs pending     |

## 5. Required workflow contracts

Field names below describe **semantic data requirements**, NOT verified JSON property names. Backend owners must supply actual DTOs, enum values, nullability, ID types, authorization and errors before frontend adapters are wired.

### 5.1 Hunter submission → ADM-04 → ADM-06 → Mobile

``` text
Person 2: Add Place -> current district + live GPS
  -> duplicate/restricted-zone checks -> live 360 + live normal photo
  -> review -> submit -> Pending
  -> ADM-04 authorized evidence review
     -> Approve: publish place + one 200-Coin reward + notification
     -> Reject: reason, no reward + notification
     -> Hold: only if supported by approved review contract
  -> My Hunts refresh and status detail
  -> Approved place visible through ADM-06 and eligible Traveller/Hunter reads
```

Data: submission ID, submitter user ID, place name/description/category, verified district, latitude/longitude/accuracy, protected 360 video and normal-photo evidence references, capture/submission times, duplicate candidate IDs/flags, restricted-zone result, review state, actor/reason/review timestamp, published place ID after approval, reward ledger reference or reward state.

Rules: live capture only for mandatory Hunter evidence; do not use gallery proof. A duplicate candidate within 200 m is not automatic rejection. Pending/rejected places must not enter public discovery. Only verified published places appear in eligible Traveller reads. Backend is the authority for reward posting; display actual wallet status, not assumed +200 on tap.

### 5.2 Game creation → ADM-10 creation review

``` text
Create Game -> setup -> ordered clue stages/hints -> review -> submit
  -> Pending creation review
  -> ADM-10 creation queue
     -> Approve: publish + creator 100 Coins once + expiry + notification
     -> Reject: reason + no reward
  -> Mobile My Games / eligible public game list
```

Data: game ID, creator user ID, title/description, district, ordered stage IDs, clue media references and hints, review state, submission/approval/expiry UTC timestamps, reviewer and rejection reason, reward reference.

Expiry = exactly 720 hours after Admin approval. Expired games leave public/playable lists and remain in authorized My Games/history/Admin archive. No start, resume, completion or winner approval after expiry. The server evaluates expiry; device time is display-only. Creator clue gallery policy is unresolved; do not conflate it with mandatory live player proof.

### 5.3 Game playing → ADM-10 completion/winner review

``` text
Eligible game -> accept -> attempt ID -> current stage
  -> live camera proof -> backend validation
     -> Accepted: next stage
     -> Rejected: policy-allowed retry; 3 rejected proofs closes attempt
  -> submit completion -> Pending final verification
  -> ADM-10 completion queue (separate from creation queue)
     -> Eligible verified winner: winner 100 Coins once + notification
     -> Reject: reason; no reward; retry only if approved policy permits
  -> Mobile result + My Games + wallet refresh
```

Data: attempt ID, game ID, player user ID, stage ID, proof ID, protected live evidence, capture/start/completion timestamps, rejected proof count, attempt and review states, reviewer/reason, winner user ID, reward reference.

Rules: no creator playing/winning own game; no more than one verified winner per game; concurrent winner approvals must not produce a second winner or reward. Pending completion is not victory. Close competing attempts according to approved backend behavior. Detailed retry scope and creator-gallery policy require owner confirmation. Do not add a compulsory game map or distance meter.

### 5.4 Coins and voucher redemption → ADM-11/12/13

``` text
Admin ADM-12 publishes valid offer and inventory
  -> Person 2 Wallet -> offers -> eligibility -> request
  -> backend reserves 10,000 Coins; Pending
  -> ADM-13 review of same request ID
     -> Reject or allowed user cancellation: release reservation once
     -> Approve: consume reservation + permanently debit once
        -> Approved, waiting for issue
        -> Issue sample voucher (unique code/image/QR)
  -> Mobile request detail + issued voucher + wallet refresh
  -> ADM-11 ledger and reconciliation
```

Demo offer: LKR 100 sample voucher; costs 10,000 Coins and requires at least 10,100 spendable Coins. No real cash payout. Use backend offer/eligibility values; do not invent or hardcode a rule for unrelated future offers.

Data: wallet owner user ID, spendable/reserved/posted/lifetime-earned amounts, offer ID, request ID, reservation reference, cost/minimum spendable/currency value, request state, separate issuance state, reviewer/reason, inventory/issued voucher ID, protected voucher code/image/QR, ledger reference and timestamps.

Example with 12,500 posted/spendable Coins (illustrative only):

| State                           | Spendable | Reserved | Posted |
|---------------------------------|----------:|---------:|-------:|
| Before request                  |    12,500 |        0 | 12,500 |
| Pending hold                    |     2,500 |   10,000 | 12,500 |
| Approved permanent debit        |     2,500 |        0 |  2,500 |
| Issued                          |     2,500 |        0 |  2,500 |
| Rejected/cancelled from Pending |    12,500 |        0 | 12,500 |

No second debit on issue/retry. If issue fails, preserve approved debit and expose controlled retry; no automatic refund. Do not show code/QR before successful issuance. Use authorized sample vouchers only. The ledger is the only authoritative coin balance. Welcome +100 once after verified registration; Hunter +200 once after approval; Game creator +100 once after approval; winner +100 once after final verification. Never increment Coins in frontend storage. Lifetime-earned level threshold is a separate contract and must be confirmed.

### 5.5 Traveller safety → ADM-08 and ADM-09

``` text
Person 1: planned trip -> active session -> report hazard with live photo/GPS
  -> backend persists report -> ADM-08 verify/resolve/flag if supported
  -> eligible route-matched Traveller warnings -> refresh

Trip invitation -> recipient accepts -> membership
  -> separate explicit location sharing consent -> authorized sharing
  -> pause/resume/recover/finish; I'm Safe -> authorized safety notification
  -> ADM-09 authorized session audit
```

Hazard data: hazard ID, trip-plan ID, reporter ID, hazard type/description, coordinates, protected photo reference, photo capture timestamp, stored report timestamp, verification/resolve state, expiry timestamp and review metadata. Alert only for planned routes within 1 km; expires 24 hours after stored report timestamp. Show real photo timestamp and review state. Never fabricate a verified hazard. GPS sharing is separate from follow and trip invitation; accepted membership is not consent. Stop sharing when consent is revoked or session is finished; enforce permitted access on backend. No fake map routes or distance values.

### 5.6 Identity → ADM-01/03/17

Mobile register/OTP/login/profile/logout uses the existing Identity backend. Admin authentication and roles must use the approved Admin contract; do not reuse mobile auth as implied Admin access. Admin warning/suspension/reactivation must enforce the approved backend policy. Protect account state and private profile data. Show suspension/session-expiry recovery in Mobile as specified by the real backend response. Friends requests, contacts and account management capabilities need exact confirmation.

### 5.7 Ads and campaigns → ADM-05/14/15

``` text
Admin creates ad + authorized image -> sets placement/schedule/status
  -> backend selects active eligible advertisements
  -> Person 1 Home banner / eligible sponsored POI display
  -> supported analytics only via approved backend event contract
```

Data: advertisement ID, title/description, image reference, approved destination, placement, UTC start/end time, status, approved targeting conditions. Supported placement names in inspected source: `HomeBanner`, `SponsoredPoi`. District targeting and arbitrary client-supplied query time are not supported in inspected contract. Never claim sponsorship/campaign/analytics capability without matching API support.

### 5.8 Notifications → ADM-16 and all domains

Person 1 owns mobile inbox/preferences UI. Person 2 feature screens and Admin actions depend on the backend event outcome, not direct frontend communication. Route via typed authorized destinations and refresh actual detail. Persist inbox even if push transport fails. Read state is server-backed where supported.

| Semantic event                           | Mobile destination                    |
|------------------------------------------|---------------------------------------|
| Hunter approved/rejected                 | Hunt details (submission ID)          |
| Game creation approved/rejected          | My Games/game details (game ID)       |
| Game winner verified/completion rejected | Game result (attempt ID)              |
| Voucher approved/rejected                | Request details (request ID)          |
| Voucher issued                           | Voucher details (request/voucher ID)  |
| Group trip invitation                    | Trip invitations (invitation/trip ID) |
| Eligible hazard/safety alert             | Authorized road alert/session details |

Event data: unique event ID, recipient user ID, event type, authorized entity reference, creation time, title/body or localization keys, read state. These are semantic mappings, not approved event enum names. Validate links and ownership before loading private detail. Unknown event types fall back to an inbox/detail view rather than failing.

### 5.9 Places and ranking across modules

Traveller place selection may consume only eligible provider results and backend-published Hunter places. Pass a stable place reference and source type; do not assume provider IDs equal Hunter place IDs. Historical route reuse must use approved eligibility and copy contract. Shared leaderboard UI supports Traveller/Hunter/Game with source-specific data. No fabricated ranks or client-computed combined score. Exact ranking and list contracts require confirmation.

## 6. Source-verified HTTP inventory (not runtime-verified)

Snapshot: backend `develop` inspected on 2026-11-22. These are controller/contract paths observed in source; do not infer deployment, matched DTOs, SQL persistence, authorization success or runtime readiness. Re-check current branch/commit before integration. Paths with `{...Id}` represent server identifiers; consult real route constraints and DTOs. Do not call these paths with guessed bodies.

### Identity (M1)

Base: `/api/mobile/identity`

| Method | Relative path      |
|--------|--------------------|
| POST   | `/register`        |
| POST   | `/verify-otp`      |
| POST   | `/resend-otp`      |
| POST   | `/login`           |
| POST   | `/forgot-password` |
| POST   | `/reset-password`  |

Source: `Controllers/Mobile/IdentitySocial/IdentityAuthenticationController.cs`, `Contracts/IdentityApiContract.cs` under `src/Wayhunter.Api/`. Profile and logout controllers also present; inspect exact actions and token/DTO behavior. Reset request uses `Email`, `Token`, `NewPassword`, `ConfirmPassword` in source; do not assume registration OTP is interchangeable with recovery token. Admin Identity/Friends HTTP coverage remains unconfirmed.

### Traveller and trips (M2/M3)

See `docs/m2-backend-completion/M2_BACKEND_ENDPOINT_INVENTORY.md` for actual trip planning inventory, and `Controllers/Mobile/TravelPlanning/` and `Controllers/Mobile/TripSafety/` for DTOs/routes. Observed mobile trip-planning base `/api/mobile/trip-plans` covers plan CRUD, stops, suggestions, AI generation, route preview, place queries and weather. Suggested plan copy fails closed in previously inspected implementation; never present a successful real copy without runtime evidence.

| Side   | Method | Path                                                        |
|--------|--------|-------------------------------------------------------------|
| Mobile | POST   | `/api/mobile/trips/{tripPlanId}/hazards`                    |
| Mobile | GET    | `/api/mobile/trips/{tripPlanId}/hazards`                    |
| Admin  | POST   | `/api/admin/hazards/{hazardId}/verify`                      |
| Admin  | POST   | `/api/admin/hazards/{hazardId}/resolve`                     |
| Admin  | GET    | `/api/admin/safety/trips/{tripPlanId}/sessions/{sessionId}` |

Source: `Controllers/Mobile/TripSafety/TripHazardsController.cs` (includes Admin actions), `Controllers/Admin/TripSafety/AdminSafetyController.cs`. Hazard Admin queue/list/flag routes not confirmed. Review session actions, group invitations, consent, safe check-in and memories controllers for exact remaining routes.

### Coins and vouchers (M6)

Mobile base `/api/mobile/coins-wallet`:

| Method | Relative path                                   |
|--------|-------------------------------------------------|
| GET    | `/me`                                           |
| GET    | `/me/transactions`                              |
| GET    | `/vouchers/offers`                              |
| POST   | `/vouchers/requests`                            |
| GET    | `/vouchers/requests/{requestId}`                |
| POST   | `/vouchers/requests/{requestId}/cancel`         |
| GET    | `/vouchers/requests/{requestId}/issued-voucher` |

Admin base `/api/admin/coins-wallet/vouchers`:

| Method | Relative path                   |
|--------|---------------------------------|
| GET    | `/requests`                     |
| POST   | `/offers`                       |
| POST   | `/inventory`                    |
| POST   | `/requests/{requestId}/approve` |
| POST   | `/requests/{requestId}/reject`  |
| POST   | `/requests/{requestId}/issue`   |
| POST   | `/requests/{requestId}/use`     |
| POST   | `/expiry/run`                   |

Admin ledger base `/api/admin/coins-wallet`:

| Method | Relative path                     |
|--------|-----------------------------------|
| POST   | `/ledger/{ledgerEntryId}/reverse` |
| POST   | `/rule-versions`                  |
| GET    | `/rule-versions`                  |
| GET    | `/reports/operations`             |
| GET    | `/reports/reconciliation`         |

Source: `Controllers/Mobile/CoinsWallet/MyCoinWalletController.cs`, `MyCoinTransactionsController.cs`, `SampleVoucherRequestsController.cs`, and `Controllers/Admin/CoinsWallet/SampleVoucherAdminController.cs`, `CoinAdministrationController.cs`. Mobile My Requests/My Vouchers collection endpoints are not confirmed; individual request/issued voucher reads are present. Do not invent collection paths. Ledger reversal is a controlled Admin action, not normal redemption cancellation.

### Advertisements (M7)

| Side   | Method | Path                                                  |
|--------|--------|-------------------------------------------------------|
| Mobile | GET    | `/api/mobile/advertisements/active` (placement query) |
| Admin  | GET    | `/api/admin/advertisements`                           |
| Admin  | POST   | `/api/admin/advertisements`                           |
| Admin  | GET    | `/api/admin/advertisements/{advertisementId}`         |
| Admin  | PUT    | `/api/admin/advertisements/{advertisementId}`         |
| Admin  | PATCH  | `/api/admin/advertisements/{advertisementId}/status`  |

Source: `Controllers/Admin/HomeAdsAnalytics/AdvertisementsController.cs`, `AdvertisementImageUploadController.cs`, `Controllers/Mobile/HomeAdsAnalytics/ActiveAdvertisementsController.cs`, `Contracts/HomeAdsAnalytics/AdvertisementAdminEndpointContract.cs`, `AdvertisementMobileReadEndpointContract.cs`. Image upload contract metadata proposes POST `.../{advertisementId}/image`; verify actual controller action/content type before wiring.

### Notifications (M3)

| Side   | Method  | Path                                                  |
|--------|---------|-------------------------------------------------------|
| Mobile | GET     | `/api/mobile/notifications`                           |
| Mobile | PUT     | `/api/mobile/notifications/{eventId}/read`            |
| Mobile | GET/PUT | `/api/mobile/notifications/preferences`               |
| Mobile | PUT     | `/api/mobile/notifications/devices/{deviceId}`        |
| Mobile | POST    | `/api/mobile/notifications/devices/{deviceId}/revoke` |
| Mobile | PUT     | `/api/mobile/notifications/reminders`                 |
| Mobile | POST    | `/api/mobile/notifications/reminders/{jobId}/cancel`  |
| Admin  | POST    | `/api/admin/notifications/preview`                    |
| Admin  | POST    | `/api/admin/notifications/schedules`                  |
| Admin  | POST    | `/api/admin/notifications/schedules/{jobId}/cancel`   |
| Admin  | GET     | `/api/admin/notifications/schedules/{jobId}/summary`  |

Source: `Controllers/Mobile/TripSafety/NotificationsController.cs`, `Controllers/Admin/TripSafety/AdminNotificationsController.cs`. Inspect actual request types, required operation IDs and authorization policies. Admin preview/schedule availability does not establish a complete arbitrary notification sending contract.

### Hunter and Games (M4/M5)

No paired mobile/Admin HTTP controllers for these domains were confirmed in the inspected `develop` controller inventory. Service/domain implementation may exist on other feature branches. Required capabilities: submit and read own evidence/attempts, member-authorized media upload/read, paginated Admin queue/detail, server-authorized approve/reject, published reads, reward linkage, and source-specific ranks. M4/M5 backend owners must provide exact merged routes and DTOs. **Do not create guessed API strings in production frontend adapters.** Use isolated mock adapters with explicit demo labels until approved contracts exist.

## 7. API handoff template — required for every operation

Each backend owner fills one record per endpoint and shares it with Mobile and Admin before wiring. Include an OpenAPI excerpt or actual DTO source, plus sanitized success/error examples. Example values must be obviously synthetic.

``` yaml
# TEMPLATE ONLY — not an actual API schema
operation: TBD
owner: TBD
mobile_screens: []
admin_pages: []
method: TBD
route: TBD
query_and_path_parameters: TBD
request_content_type_and_dto: TBD
response_dto_and_success_status: TBD
field_types_nullability_and_enum_serialization: TBD
authentication_and_required_policy: TBD
allowed_state_transitions: TBD
error_status_and_response_dto: TBD
pagination_sort_filter: TBD
idempotency_and_concurrency: TBD
side_effects_and_notification_types: TBD
source_file_branch_commit: TBD
runtime_test_evidence: TBD
status: DECISION_REQUIRED
```

Contract agreement includes exact JSON casing/enum representation, GUID or other identifier type, UTC time format, pagination shape, error body, nullable fields, media content type/access, retry safety, timeout, authorization and conflict handling. Never force all domain states into one shared enum. Typical UI fallback handling for unauthorized, forbidden, conflict, validation and service-unavailable errors must map to the actual endpoint contract.

## 8. State and UI mapping (proposed presentation only)

| Meaning             | Suggested display                | Rule                                                   |
|---------------------|----------------------------------|--------------------------------------------------------|
| Pending review      | Amber / Waiting for review       | No reward and no publication assumed                   |
| Approved            | Green / Approved                 | Domain-specific meaning; voucher approval is not issue |
| Rejected            | Red / Rejected + reason          | No assumed reward; display authorized reason           |
| Active              | Cyan / Active                    | Backend eligibility controls actions                   |
| Expired/Archived    | Grey / Expired                   | Not playable; authorized history retained              |
| Cancelled           | Grey / Cancelled                 | Allowed transition only                                |
| Issued              | Green / Voucher available        | Show code/QR only after successful authorized fetch    |
| Unknown/unavailable | Neutral / Refresh or unavailable | Never turn unknown into Approved                       |

Exact wire status values are DECISION_REQUIRED until the endpoint DTO/enum is checked. Preserve distinction between game creation status, attempt status, winner status, reward status, redemption request status, issuance status and hazard verification state. If reward posting is asynchronously pending, show only the actual authoritative ledger outcome.

## 9. Blocking decisions and owner action list

| Priority | Owner               | Required confirmation                                                                                                              |
|----------|---------------------|------------------------------------------------------------------------------------------------------------------------------------|
| P0       | M1                  | Real mobile/admin authentication policies, session expiry, suspension and user ID contract; Admin auth routes                      |
| P0       | M4                  | Hunter mobile and Admin HTTP routes, evidence upload/read, approval transaction and published place contract                       |
| P0       | M5                  | Game create/play/attempt/review/rank routes, final winner concurrency, expiry rules, proof retries and creator clue media decision |
| P0       | M6                  | Exact offer/request/hold/issue DTOs, idempotency, list endpoints for My Requests/My Vouchers and reward linkage                    |
| P0       | All                 | Shared API environment, commit/version, sample fixtures and expected error responses                                               |
| P1       | M3                  | Hazard queue/flag actions, session permissions, event/deep-link mapping and notification delivery                                  |
| P1       | M2 + M4             | Approved place source IDs and cross-module search/reuse; suggested copy/historical plan readiness                                  |
| P1       | M5 + ranking owners | Source-specific leaderboard contracts and rank qualification                                                                       |
| P1       | M7                  | Ad upload contract, campaign/sponsored eligibility and analytics APIs; district targeting readiness                                |
| P1       | M1 / feature owners | Friends, contacts matching, profile posts, report-issue and account-management scope/endpoint confirmation                         |

P0 blocks the related live integration, not independent mock UI work. Do not mark a blocked workflow as production complete. Current source-only inspection does not establish that any endpoint works against the deployed database. No live API/SQL/E2E tests have been run as part of this handoff.

## 10. End-to-end acceptance checklist

All tests start with separate authorized mobile and Admin accounts in the same non-production environment. Record sanitized actual entity IDs, involved commits, expected/actual results and PASS/FAIL/BLOCKED. A mock demo is not an E2E pass.

- [ ] Registration verification credits +100 once; repeated OTP success does not duplicate the welcome reward.
- [ ] Mobile user without Admin role cannot invoke protected review/issue actions; unauthorized data is not returned.
- [ ] Admin suspension is enforced by backend on affected mobile actions; approved reactivation policy is respected.
- [ ] Hunter mobile submission appears in Admin queue with same ID and authorized evidence.
- [ ] Hunter approval publishes eligible place and posts +200 once; mobile status, discovery and wallet refresh agree.
- [ ] Hunter rejection shows authorized reason, no publication or reward; 200 m duplicate candidate is handled per approved policy.
- [ ] Game creation approval posts +100 once and sets expiry exactly 720 hours after approval; rejection posts no reward.
- [ ] Creator cannot play own game; only eligible public games can be started.
- [ ] Player live proof and rejection count are enforced; three rejected proofs closes the attempt.
- [ ] Final completion pending is not victory; concurrent winner approvals result in at most one verified winner and one winner reward.
- [ ] Expired game is not publicly playable; no start/resume/completion/winner approval after expiry; archive remains available to authorized users.
- [ ] Spendable 10,099 Coins fails demo redemption; 10,100 satisfies minimum and reserves 10,000 if all other validations pass.
- [ ] Pending request appears in ADM-13 with same ID; balance/reservation reconcile.
- [ ] Reject or permitted cancel releases exactly once; simultaneous approve/cancel cannot double-settle.
- [ ] Approve permanently debits exactly once; repeated approval does not duplicate debit.
- [ ] Issue exposes one unique sample voucher image/code/QR only after successful issue; retry does not debit again.
- [ ] Failed issue preserves approved debit; controlled retry works without an automatic refund or duplicate issuance.
- [ ] A different user cannot read another user's voucher, private evidence or location.
- [ ] Report hazard displays real capture timestamp, route matching within 1 km and 24-hour expiry; verification state updates correctly.
- [ ] Invitation acceptance creates membership; location consent remains separate, revocable and enforced.
- [ ] Admin active advertisement appears only in eligible mobile placement and schedule; disabled ad is excluded.
- [ ] Committed approval/rejection/issue produces persistent relevant inbox event; push failure does not lose state; deep link resolves to authorized detail.
- [ ] App restart/refresh reads persisted status, not stale mock/local state.
- [ ] Backend retry/concurrency tests protect reward, redemption and winner invariants; Admin audit shows actor/reason/time.
- [ ] Flutter analyze/test/build and Angular lint/test/build pass under repository-approved commands; real integration tests have separate evidence.

## 11. Delivery order (3-day mobile UI target)

| Stage | Mobile teams                                                                   | Admin team                                           | Backend owners                                                |
|-------|--------------------------------------------------------------------------------|------------------------------------------------------|---------------------------------------------------------------|
| Day 1 | Common foundation, lock route/reference contracts, start independent features  | Admin foundation, queue/detail UI skeletons          | Confirm current API inventory + P0 contracts/environment      |
| Day 2 | Independent feature UI, mock adapters and available real adapters              | Independent review/action pages, available real APIs | Resolve blocked routes/DTOs, prepare safe fixtures            |
| Day 3 | Merge feature branches, route smoke tests, available live end-to-end workflows | Admin action/refresh tests and integration           | Test state transitions, security, idempotency and persistence |

Three days is a UI prototype delivery target, not a guarantee of production-ready integration. Real maps, GPS, camera/360 capture, secure media, full Admin authorization, database migrations and all end-to-end flows require working provider/device/backend dependencies and separate runtime verification.

Maintain canonical contracts in a reviewed SecondBrain location, proposed `docs/integration/WAYHUNTER_MOBILE_ADMIN_INTEGRATION.md`. Link/copy the approved version into each repository. Use existing Git branch/PR workflow; do not push directly to main. Freeze shared routing/theme/auth/API contract files between independent workstreams. Change a contract only after affected owners agree and both frontends' tests/fixtures are updated.

## 12. Codex startup prompt (copy into each developer's session)

``` text
Read WAYHUNTER_MOBILE_ADMIN_INTEGRATION.md completely and follow this repo's
AGENTS.md, active SecondBrain rules and member ownership guidance.

My assigned role is: [Mobile Person 1 / Mobile Person 2 / Admin module(s) /
Backend member M1-M7]. My assigned modules are: [fill in].

First inspect the current git branch/status and existing code. Do not overwrite
unrelated changes. Check the approved SecondBrain rules and actual backend
controllers, DTOs, authorization policies and OpenAPI before selecting API paths.

Return a read-only implementation report:
1. Current branch and source commit, existing relevant files and modules.
2. KEEP / MODIFY / ADD plan with exact ownership boundaries.
3. Mobile screen <-> Admin page <-> backend endpoint mapping for my scope.
4. Exact request/response DTOs, identifiers and status transitions, distinguishing
   APPROVED_RULE, CODE_VERIFIED, PROPOSED, DECISION_REQUIRED and RUNTIME_VERIFIED.
5. Missing endpoints / unresolved decisions with responsible owner and impact.
6. Test cases and safe mock vs real adapter strategy.
7. Task sequence for my assigned scope and planned changed files.

Do not implement until the plan is reviewed. After approval, work only on my
assigned branch and owned files. Keep UI and API adapters separate. Do not invent
missing endpoints or enum values, produce fake rewards/verification/routes,
access SQL directly from a frontend, expose admin actions in mobile production,
or commit secrets. Coordinate shared contract changes before editing them.

Before reporting completion, run applicable tests and show actual evidence.
Report mocked, blocked and runtime-verified work separately. Never mark an
untested or mock-only flow as production complete.
```

## 13. Handoff approval and verification record

| Item                                    | Responsible party          | Status                              |
|-----------------------------------------|----------------------------|-------------------------------------|
| Mobile allocation and common foundation | Mobile Person 1 + Person 2 | Proposed / awaiting team acceptance |
| Admin page ownership                    | Admin team                 | Assign per module                   |
| Exact backend contract approval         | M1–M7 owners               | Pending per operation               |
| Shared environment and fixture IDs      | Backend + QA               | Pending                             |
| Live E2E results                        | All affected teams         | Not run in this handoff             |

Prepared from the preceding project planning and inspected `develop` source routes. This document intentionally distinguishes suggested semantic fields, design choices and missing API capabilities from actual source-declared routes. No repository files were changed, no contract has been approved on behalf of an owner, and no tests were executed during document creation. Reconcile against the current branch/commit before using it as a locked team baseline.
