# Person 1 demo handoff

## Frontend behavior

- Language settings show English as the available interface language. Tamil and Sinhala need translated strings and a separately reviewed app-wide locale integration.
- The server-confirmed completed summary opens the existing authenticated Trip Memories route. The screen still displays the service's unavailable state when appropriate.
- An unconfirmed Start blocks repeat Start within the current authenticated shell. An unconfirmed Finish attempts a status read and shows an error if recovery cannot confirm the result. No completion is inferred from a timeout or a 404.
- Versioned stop deletion remains disabled until the required header can be sent. Provider errors remain visible, and missing hazard geometry does not establish that a route has no hazards.

## Backend and staging dependencies

These findings reflect the permitted backend reference source. Staging deployment and Android hardware behavior require verification.

| Priority | Dependency | Required evidence or contract |
| --- | --- | --- |
| Demo core | Approved HTTPS staging URL | Supply the origin for `WAYHUNTER_API_BASE_URL` and verify identity, JWT, OTP and recovery mail with staging accounts. |
| Demo core | M2 persistent SQL repository | Configure `TravelPlanning:EnableSqlPersistence` and apply migrations. Confirm saved plans survive restart and return valid RowVersion values for editing. |
| Demo core | M3 persistent session repository | Configure `TripSafety:EnableSqlPersistence` and apply migrations. Confirm active and finished state survive backend restart. |
| Demo core | Start and Finish reconciliation | Agree on an authorized session lookup by plan or an idempotent Start replay that returns the session ID after a lost response. This also supports app restart recovery. Existing recovery requires a session ID and returns 404 once finished. Agree on an authorized read that returns authoritative Finished status, matching plan/session IDs and the finish timestamp. Verify lost responses before enabling new client recovery behavior. |
| Feature demo | Notifications provider | Replace the unavailable binding and verify inbox, read state and preferences. |
| Feature demo | Invitation eligibility provider | Configure eligibility and the block relationship check. Verify eligible and denied invitations. Acceptance must leave GPS consent unchanged. |
| Feature demo | Hazard route provider | Provide planned-route geometry. Verify the 1 km eligibility rule and 24-hour active window against server timestamps. |
| Feature demo | Memories store and media provider | Verify owner-scoped list, create, read and delete against a configured store. Attachments require an approved private upload and media access contract. |
| Feature demo | Versioned stop removal | Preserve the verified `If-Match` RowVersion requirement. Adding bounded header support to the shared frontend client requires separate review. |

Before claiming a live end-to-end demo, run the authenticated trip journey on a physical Android device against staging and verify process restart, logout, account switching and unavailable states.
