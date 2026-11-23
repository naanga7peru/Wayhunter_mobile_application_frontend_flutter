# Person 2 manual smoke test

Use an approved non-production environment for authenticated checks and a healthy Android device for location and live capture. Keep codes, tokens and exact coordinates out of shared test records.

| Check | Expected behavior |
| --- | --- |
| At widths 320, 360, 400 and 430, open Hunter, Game Zone, Wallet and all ranking tabs | Scrollable content, readable labels, working Back, no clipped controls at large text. |
| Hunter draft, keyboard, blank and valid inputs | Errors on blank input. Valid review preserves the draft on Back. No pending status without accepted server submission. |
| Hunter GPS and live evidence | Denied/blocked permissions and unavailable device services are visible. Capture uses the live interfaces. District, nearby duplicate and restricted-place validation must await verified contracts. |
| Game draft and play | Setup and stage editors keep local data on Back. Production results require server review. Check server expiry boundary with a matching backend snapshot. |
| Wallet at 10,099 and 10,100 spendable Coins | Low balance prevents request creation. Confirmation explains the hold. Accepted requests display the server state and request ID. |
| Uncertain Wallet response, cancellation and refresh | Reconcile the original request ID before retry. Pending may cancel with a reason. Refresh status and balance from the server. |
| Voucher lookup and issuance | Only owner can open details. Approved and unissued show no code/QR. Issued status shows the authorized code and QR. Used/expired states suppress redeemable output. |
| Leaderboard category and navigation | Categories remain independent. Without official data show unavailable. Verify typed profile navigation when authorized profile data is available. |

## Execution evidence

The automated widget suites use synthetic dependencies. No production API calls, live Admin decisions or native camera/GPS checks were performed.

| Command | Result |
| --- | --- |
| flutter pub add qr_flutter | Resolved qr_flutter 4.1.0 and qr 3.0.3 in the preserved worktree. |
| flutter analyze | RUNTIME_VERIFIED no issues found. |
| flutter test --no-pub --reporter expanded | RUNTIME_VERIFIED 118 passed, 0 failed. New Wallet widget tests cover 10,099/10,100 eligibility, timeout reconciliation, cancellation and issuance gating with MOCKED dependencies. |
| flutter build web --no-pub | RUNTIME_VERIFIED success, build/web. Wasm dry run succeeded. Flutter emitted a CupertinoIcons font warning. |
| Interactive Chrome, APK, Android device and authenticated backend smoke | Not run in this Person 2 validation. |
