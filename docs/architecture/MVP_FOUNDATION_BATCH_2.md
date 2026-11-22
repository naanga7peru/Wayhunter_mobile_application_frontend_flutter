# WayHunter shared design system · Batch 2

Use `WayhunterPageScaffold` for standalone gradient pages. Shell destinations already sit on the shared gradient and can use `WayhunterHeader`, a scrollable body, and `WayhunterSurfaceCard` directly. Use the spacing, shape and module colors in `wayhunter_tokens.dart`. Module accents are Traveller cyan, Hunter green and Game purple.

`WayhunterButton`, `WayhunterTextField`, and `showWayhunterConfirmation` share Material styles. Loading, empty, error and unavailable views accept caller copy, with a callback for retry. Pass a display label and tone to `WayhunterStatusIndicator` after interpreting the feature state. The owning feature handles business rules.

The Home scenic background is the approved `wayhunter_auth_home_bg.png`, copied unchanged from the UI reference. Its artwork includes the brand mark. The three original transparent module banners listed in SecondBrain were unavailable in the inspected reference folders. The available prototype button artwork contains embedded English, so Home uses native text and module icons. The scenic art is reserved for Home and future Sign In.

`WayhunterStrings` provides shared control labels for `en`, `ta`, and `si` with English fallback. Widgets accept feature copy as parameters. The starter runs in English. App locale selection, Material localization, translated feature copy, and Android glyph review remain future work.
