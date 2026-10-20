# MAKE.md — QuitCash Mobile

This file is the single entry point to build, test and run this project.
Follow the steps in sequence. Do not skip steps.

## 1. Scope

1.1 This project is the QuitCash Flutter app.
1.2 The launch build is client-side only. It has no backend and no server cost.
1.3 All data stays on the device (shared_preferences).
1.4 The `quit-cash-api` backend is not part of this project.

## 2. Requirements

2.1 Install Flutter SDK, stable channel, Dart 3.10 or later.
2.2 Make sure that `flutter` is on `PATH`.
    - Example: `git clone --depth 1 -b stable https://github.com/flutter/flutter.git ~/flutter`
    - Then: `export PATH="$HOME/flutter/bin:$PATH"`
2.3 For Android builds, install Android SDK. For iOS builds, use macOS with Xcode.
2.4 For web builds and screenshots, install Google Chrome.

## 3. Get dependencies

3.1 Go to the project root (the folder with this file).
3.2 Run: `flutter pub get`

## 4. Do the checks

4.1 Run: `dart format --output=none --set-exit-if-changed lib test tool`
4.2 Run: `flutter analyze`
4.3 Make sure that the result is "No issues found".
4.4 Run: `flutter test`
4.5 Make sure that the result is "All tests passed".

## 5. Run the app

5.1 Web (fastest check): `flutter run -d chrome`
5.2 Android device or emulator: `flutter run -d android`
5.3 iOS simulator (macOS only): `flutter run -d ios`
5.4 Linux desktop: `flutter run -d linux`

## 6. Build release artifacts

6.1 Web: `flutter build web --release`. Output: `build/web/`.
6.2 Android: `flutter build appbundle --release`. Output: `build/app/outputs/bundle/release/`.
6.3 iOS (macOS only): `flutter build ipa --release`.
6.4 CAUTION: Android release signing and iOS signing are not configured yet.

## 7. Make the coin animation (optional)

7.1 Run: `flutter test tool/coin_frames_test.dart --dart-define=OUT=/tmp/frames`
7.2 Run: `ffmpeg -framerate 30 -i /tmp/frames/f%03d.png -loop 0 coin-spin.gif`

## 8. Project map

| Path | Purpose |
|------|---------|
| `lib/main.dart` | Entry point. Selects the repository. |
| `lib/data/` | `SavingsRepository` seam, on-device and in-memory implementations. |
| `lib/game/progress.dart` | Pure game rules: dollar-milestone levels, coins, streaks, achievements. |
| `lib/state/savings_model.dart` | App state (`ChangeNotifier`). Returns celebrations. |
| `lib/ui/widgets/coin_painter.dart` | The 3D spinning gold coin (CustomPainter). |
| `lib/ui/widgets/effects.dart` | Flying coins, burst, ticking numbers, coin rain. |
| `lib/ui/screens/` | Onboarding, Bank (home), Trophies. |
| `test/` | Unit and widget tests. |

## 9. Add a backend later

9.1 Write a new class that implements `SavingsRepository`.
9.2 Change the repository in `lib/main.dart`.
9.3 Do not change the UI or the game rules. They use only the interface.

## 10. Rules

10.1 Use idiomatic Dart lints (`analysis_options.yaml`).
10.2 Keep `flutter analyze` and `flutter test` clean before each commit.
10.3 Do not add copyrighted game assets. All coin art is drawn in code.

## 11. Game rules (reference)

11.1 Level comes only from total dollars saved.
11.2 Level 0 ("Starter") is before the first $1.
11.3 Thresholds: L1 $1, L2 $20, L3 $50, L4 $100, L5 $200, L6 $500, L7 $1000.
11.4 After L7, each additional $1000 gives one level ($2000 = L8, $3000 = L9).
11.5 Coins are cosmetic. A save gives 1 coin per $1. A daily check-in gives 5 coins.
11.6 Coins do not add to total saved and do not change the level.
11.7 A save or a check-in on a day keeps the streak alive.
