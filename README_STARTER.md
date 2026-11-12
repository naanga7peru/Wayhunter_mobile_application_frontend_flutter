# Wayhunter Flutter — runnable starter (not finished UI)
- Flutter 3.47.x target, Dart 3.x; Android/Web platform files come from official `flutter create`.
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
