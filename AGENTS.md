# AGENTS.md — Wayhunter Flutter Mobile (Codex team rules)

    **Repository:** https://github.com/naanga7peru/Wayhunter_mobile_application_frontend_flutter
    **Technology direction (proposed):** Flutter feature-first / Clean Architecture / MVVM / Riverpod
    **Module scope:** Auth, Traveler, Friends, Hunter, Game, Profile, Coins Wallet, Maps, Notifications.

    ## Required process
    1. Project owner reports **folder structures and development have not begun**. Before scaffolding, check whether a repository has existing files; GitHub source is **not code-verified** (previous connector 404).
    2. **Read `docs/second-brain/ACTIVE_RULES.md` first**, then `docs/second-brain/CONTEXT.md` and the draft Master BRD; no file proves implemented behavior.
    3. Distinguish `SOURCE`, `PROPOSED`, `CODE_VERIFIED`, `DECISION_REQUIRED`. Do not invent endpoints/tables/routes.
    4. Make a KEEP / MODIFY / ADD plan with testing before patching. Do not silently alter working UI, branch history, or schema.
    5. **VCH-DEC-01 RESOLVED:** request requires >=10,100 spendable; reserve 10,000; **Admin Approve debits 10,000 once**; reject releases. OCR/barcode *intake* optional, demo voucher QR generation/display required.
    6. Never commit API secrets, production OTP, voucher codes, raw contacts or GPS trails. Use least-privilege auth, backend validation, audit/idempotency.
    7. Never claim a feature complete just because a screenshot or previous demo repo showed it.

    ## Repo-specific rules
    - Use agreed UI reference designs/flow when creating the new app; do not assert the new repo already has screens. Navigation: Home / selected module / Leaderboard / Profile.
- No HP/RC/XP; Coins awards and statuses from backend only.
- Hunter live camera, guided 360+normal photo; gallery evidence forbidden. Pending/Approved/Rejected in My Hunts.
- Game creator image hints may be gallery; player proof live camera, creation/completion approvals separate.
- Friends page reused from Profile and Create Trip; social following != trip invite != GPS sharing consent.
- Wallet Pending reserves 10,000 with >=10,100 spendable precheck; final debit is backend Admin Approve once. Flutter must display server status; QR appears only after issue.
- Use real map/Places/Routes where provider configured; no fake routes or compulsory game map hints.

    ## Additional non-negotiable active rules
- Game expiry is 30 days after Admin approval; **Archive and retain creator My Games/database record**, NOT physical DB deletion.
- One verified winner per Game. Hazard warnings: 1 km from planned trip route, photo capture time, 24-hour active window.
- No new commercial payout scope; academic demo voucher uses sample image, unique code and QR.
- M1–M7 ownership in central `knowledge/TEAM_GIT_WORKFLOW.md` is planning allocation, not a product-rule change.

## Evidence requirements for every PR
    Mention BRD rule / Admin module, branch/commit, actual changed files, tests run, risks, any remaining `Decision Required`. No direct main push without review.
