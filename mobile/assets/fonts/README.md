# Urdu font

The scope bundles **Jameel Noori Nastaleeq** with the app for all Urdu text (Tools table; M3 FE-1). The font file is not in the repository yet. Add it like this:

1. Check that its licence allows bundling the font in the app and publishing it in this public repository.
2. Copy the file here as `JameelNooriNastaleeq.ttf` (that exact name).
3. In `mobile/pubspec.yaml`, uncomment the `fonts:` block at the end of the `flutter:` section.
4. Run `flutter pub get` and restart the app.

The theme already uses the family name `JameelNooriNastaleeq` (`lib/theme/app_theme.dart`). Until the file is added, Android falls back to the phone's default Urdu font.
