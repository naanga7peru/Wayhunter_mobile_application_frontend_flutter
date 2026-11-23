# Person 2 frontend completion matrix

Frontend baseline: feature/mobile-person2-integration at 83f02da. Backend evidence: local feature/m4-final-backend-integration at 75e39ae, with pre-existing backend worktree changes. No backend writes were made.

| Flow and route | Frontend source | Evidence and remaining work |
| --- | --- | --- |
| Hunter Home and leaderboard shortcut, hunter.home | hunter/presentation/hunter_screens.dart | CODE_VERIFIED typed Hunter leaderboard destination. Published discovery and district lookup are BLOCKED. |
| Place draft, validation, device actions and review, hunter.addNewPlace | hunter/presentation/hunter_screens.dart | CODE_VERIFIED local name/description and review. Device operations use existing permissions, location and live camera interfaces. Category taxonomy, verified district, duplicates, restricted places, protected evidence, submission and confirmation are BLOCKED. |
| My Hunts and status details, hunter.myHunts | hunter/presentation/hunter_screens.dart and hunter/data/hunter_history_sources.dart | CODE_VERIFIED unavailable state. MOCKED debug history covers pending, approved and rejected. Owner history, rewards and authorized published place links are BLOCKED. |
| Game Zone and leaderboard shortcut, games.home | games/presentation/game_navigation.dart | CODE_VERIFIED typed Game leaderboard destination and existing creation/play/history links. |
| Game setup, stages, clues, review, games.create | games/presentation/game_creation.dart | CODE_VERIFIED local draft workflow. Hint rules, approved creation writes and creator status remain BLOCKED. |
| Discovery and details, games.play and games.details | games/data/api_games_reader.dart and games/presentation/game_read_screens.dart | Existing authenticated frontend adapter retained. CODE_VERIFIED expiry filtering on read. Matching HTTP backend snapshot and live eligibility are BLOCKED. |
| Attempts and creator history, games.myAttempts and games.myGames | games/presentation/game_read_screens.dart and games/presentation/my_games.dart | CODE_VERIFIED attempts presentation. MOCKED creator history. Real archive, attempt detail/continuation and sponsorship are BLOCKED. |
| Play instructions, challenge, live proof and results preview, games.play child routes | games/presentation/game_playing.dart | MOCKED debug previews. Acceptance, active stages, proof submission/retry and verified completion/results are BLOCKED. |
| Wallet overview, transaction pages and offers, wallet.home and child routes | wallet/presentation/wallet_screens.dart and wallet/data/repositories/api_wallet_reader.dart | CODE_VERIFIED existing owner-scoped Wallet reads and pagination. |
| Offer confirmation, request lookup and details, cancel, issuance, code and QR, wallet.home child routes | wallet/presentation/wallet_redemption_screens.dart and wallet/data/repositories/api_voucher_redemption_repository.dart | CODE_VERIFIED owner-scoped contract. APPROVED_RULE minimum 10,100 spendable Coins for a 10,000-Coin hold. MOCKED widget coverage for reconciliation, cancel and issuance. Request/voucher collections, sample image delivery and live verification are BLOCKED. |
| Traveller, Hunter and Game rankings, leaderboard.module | leaderboards/presentation/leaderboard_screens.dart | CODE_VERIFIED category switching, unavailable state and debug preview navigation. Real rankings, live refresh and authorized profile data are BLOCKED. |

Historical screenshots and debug examples are not evidence of backend behavior. Automated test outcomes are listed in the manual smoke document.
