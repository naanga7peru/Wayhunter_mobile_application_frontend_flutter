# Person 2 API gap register

## CODE_VERIFIED in backend source

All paths below require authentication. Voucher commands resolve the owner on the server. Request lookup and voucher lookup are owner-scoped; the SQL store checks owner and offer on create replay. Cancel accepts a reason and only transitions Pending. The client uses the same request UUID for retries and checks the server before replaying an uncertain create.

| Method | Path | Frontend |
| --- | --- | --- |
| GET | /api/mobile/coins-wallet/me | Balance |
| GET | /api/mobile/coins-wallet/me/transactions | Transaction pages |
| GET | /api/mobile/coins-wallet/vouchers/offers | Offers |
| POST | /api/mobile/coins-wallet/vouchers/requests | Create using requestId and offerId |
| GET | /api/mobile/coins-wallet/vouchers/requests/{requestId} | Request details and reconciliation |
| POST | /api/mobile/coins-wallet/vouchers/requests/{requestId}/cancel | Cancel using reason |
| GET | /api/mobile/coins-wallet/vouchers/requests/{requestId}/issued-voucher | Issuance and server-provided code/QR payload |

Source: MyCoinWalletController, MyCoinTransactionsController, SampleVoucherRequestsController, SampleVoucherDtos, SampleVoucherAdminDtos, SampleVoucherRequestService and SqlSampleVoucherRequestStore. Program.cs enables Swagger in development. No live OpenAPI document or endpoint was exercised. Admin actions require the Coins Wallet administrator policy and remain backend-owned.

## BLOCKED

| Owner | Missing contract or dependency | Impact |
| --- | --- | --- |
| M4 | Production Hunter routes for categories, district, draft, duplicate/restricted-place checks, protected evidence, submission, owner reads and discovery | HTTP candidate controllers appear under integration tests. No production bindings added. Traveller place-picker routes are not substitutes for approved Hunter place reads. |
| M5 | Matching deployed controller/OpenAPI snapshot for existing authenticated discovery/details/attempt reads | Existing Flutter routes GET /api/mobile/games, GET /api/mobile/games/{id} and GET /api/mobile/games/me/attempts retained. Current backend checkout did not corroborate these HTTP routes. |
| M5 | Creator writes/history, player eligibility, acceptance/resume, live proof and retry, results, sponsorship | Existing local drafts and explicitly labeled previews. No mutation binding. |
| M2/M3, M4 and M5 | Traveller, Hunter and Game ranking endpoints and typed authorized profile target | Module tabs are available. Official data stays unavailable. Person 1 owns the profile destination. |
| M6 | Owner-scoped request/voucher collection endpoints | Known-ID lookup is available. Users must retain the request ID to reopen it. |
| M6 | Protected sample image delivery contract | Response has a sample image reference. The client needs a verified fetch and authentication contract before rendering it. |
| Foundation owner and M4/M5 | Native location/live media bindings, geographic verification and protected upload | Default device services are unavailable. Production capture and submission need native and backend verification. |
