# Wayhunter Flutter — runnable starter (not finished UI)
- Verified toolchain: Flutter 3.47.9 and Dart 3.13.7. Use this pair to reproduce the current lockfile, which requires Dart >=3.13.0 <4.0.0 and Flutter >=3.38.4. The pubspec declares a Dart language floor of 3.8; the resolved packages require the newer SDK.
- M7 owns Home and shared navigation contracts; other screens are clearly labelled starter placeholders.
- Bottom tabs: Home / Selected module / context leaderboard / Profile.
- No Maps API, OTP, camera, Coins, Cloudinary or permissions have been integrated.
- Original image assets are not present in this starter; Home does not pretend to show final scenic artwork.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```
Use `Install-Flutter-Starter.ps1` to scaffold Android/Web in a temp directory and safely merge with your existing Git clone.
