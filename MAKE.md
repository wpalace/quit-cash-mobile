# MAKE.md — QuitCash Mobile

This file is the single entry point to build, test and run this project.
Follow the steps in sequence. Do not skip steps.

## 1. Scope

1.1 This project is the QuitCash Flutter app.
1.2 The launch build is client-side only. It has no backend and no server cost.
1.3 All data stays on the device (shared_preferences).
1.4 The `quit-cash-api` backend is not part of this project.

## 2. Requirements

2.1 Install Flutter SDK 3.47 stable (Dart 3.13). The house standard targets this version.
2.2 Make sure that `flutter` is on `PATH`.
    - Example: `git clone --depth 1 -b stable https://github.com/flutter/flutter.git ~/flutter`
    - Then: `export PATH="$HOME/flutter/bin:$PATH"`
2.3 For Android builds, install Android SDK. For iOS builds, use macOS with Xcode.
2.4 For web builds and screenshots, install Google Chrome.

## 3. Get dependencies

3.1 Go to the project root (the folder with this file).
3.2 Run: `flutter pub get`

## 4. Do the checks

4.1 Run: `dart format --output=none --set-exit-if-changed .`
4.2 Run: `flutter analyze --fatal-infos`
4.3 Make sure that the result is "No issues found".
4.4 Run: `flutter test`
4.5 Make sure that the result is "All tests passed".
4.6 End-to-end (optional, needs Chrome and a matching `chromedriver` on port 4444):
    - Run: `chromedriver --port=4444 &`
    - Run: `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_flow_test.dart -d web-server --browser-name=chrome --headless`
4.7 To update the golden image after an intended art change, run: `flutter test --update-goldens test/goldens`.
4.8 These are the same checks as CI (`.github/workflows/standards-check.yml`) and pre-commit (`.pre-commit-config.yaml`).

## 5. Run the app

5.1 Web (fastest check): `flutter run -d chrome`
5.2 Android device or emulator: `flutter run -d android`
5.3 iOS simulator (macOS only): `flutter run -d ios`
5.4 Linux desktop: `flutter run -d linux`

## 6. Build release artifacts

6.1 Web: `flutter build web --release`. Output: `build/web/`.
6.2 Android: `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`. Output: `build/app/outputs/bundle/release/`.
6.3 iOS (macOS only): `flutter build ipa --release --obfuscate --split-debug-info=build/symbols`.
6.5 Keep `build/symbols/` for each release. You need it to read obfuscated stack traces.
6.4 CAUTION: Android release signing and iOS signing are not configured yet.

## 7. Make the coin animation (optional)

7.1 Run: `flutter test tool/coin_frames_test.dart --dart-define=OUT=/tmp/frames`
    - Optional: add `--dart-define=DENOM=100` for the ruby or `DENOM=500` for the diamond (1, 5, 10, 20, 50 also work).
    - The tool also writes `/tmp/frames/sheet.png` with all denominations.
7.2 Run: `ffmpeg -framerate 30 -i /tmp/frames/f%03d.png -loop 0 coin-spin.gif`

## 8. Project map

| Path | Purpose |
|------|---------|
| `lib/main.dart` | Entry point. Selects the repository. Installs global error handlers. |
| `lib/domain/models/` | Immutable models and pure rules: `goal`, `habits`, `save_entry`, `tap_cluster`, `trend_report` and `trend_insights` (pure stats), `progress` (levels, achievements), `reminder_plan`. |
| `lib/data/repositories/` | `SavingsRepository` interface (returns `Result<T>`), on-device (`prefs_`) and `in_memory_` implementations. |
| `lib/data/services/reminder_service.dart` | Local notification service (no-op on web). |
| `lib/utils/` | `Result<T>` (`Ok`/`Error`) and `money()` formatting. |
| `lib/ui/core/view_models/savings_view_model.dart` | App-wide view model (`ChangeNotifier`). Returns celebrations. |
| `lib/ui/core/themes/` | Palette, denominations and metal color ramps, picker filter. |
| `lib/ui/core/widgets/` | Shared widgets: coin, ruby and diamond painters (`diamond_painter.dart`), spinning coin, flying coin, burst, coin rain, ticking number, reminder picker, celebration dialog, backdrop. |
| `lib/ui/app/`, `lib/ui/home/`, `lib/ui/goals/`, `lib/ui/history/`, `lib/ui/trends/`, `lib/ui/onboarding/`, `lib/ui/trophies/`, `lib/ui/settings/` | App shell (tabs: Bank, Goals, Trends, Trophies) and one folder per screen. |
| `test/` | Unit, widget and golden (`test/goldens/`) tests. |
| `integration_test/`, `test_driver/` | End-to-end flow (MAKE.md 4.6). |
| `.standards/`, `.standards-version`, `.standards-exclude`, `AGENTS.md` | House coding standard (vendored, do not edit). |

## 9. Add a backend later

9.1 Write a new class in `lib/data/repositories/` that implements `SavingsRepository`. Return `Ok`/`Error`; do not throw.
9.2 Change the repository in `lib/main.dart`.
9.3 Do not change the UI or the game rules. They use only the interface.

## 10. Rules

10.1 Follow the house Flutter standard: `.standards/skills/flutter/SKILL.md` (v1.2.0, pinned in `.standards-version`). Read `AGENTS.md` first.
10.4 Do not edit `.standards/`. To update it, run `bash .standards/scripts/sync-standards.sh` (set `STANDARDS_SOURCE=<local clone>` if offline).
10.5 Keep `dart format` changes in their own commit.
10.6 Record each deviation under "Declared exceptions" in `AGENTS.md`.
10.2 Keep `flutter analyze` and `flutter test` clean before each commit.
10.3 Do not add copyrighted game assets. All coin art is drawn in code.

## 11. Game rules (reference)

11.1 Level comes only from total dollars saved.
11.2 Level 0 ("Starter") is before the first $1.
11.3 Thresholds: L1 $1, L2 $20, L3 $50, L4 $100, L5 $200, L6 $500, L7 $1000.
11.4 After L7, each additional $1000 gives one level ($2000 = L8, $3000 = L9).
11.5 The app tracks one thing: dollars saved. There is no daily check-in, bonus, coin currency, XP or streak.
11.6 Badges are dollar milestones only: $1, $10, $25, $50, $100, Level 5 ($200), $500, $1000, $2500, $5000.
11.7 Streaks were removed (commit "remove streaks"). Revert that commit to restore them.
11.8 The top-bar counter shows total dollars saved. It rolls up as the flying coins land.
11.9 Old data may contain daily check-in rows (`"k": "checkIn"`). They are skipped on load (`SaveEntry.tryFromJson`) and dropped at the next save. They never counted as dollars.

## 12. Reminders (local notifications)

12.1 Onboarding asks for a frequency: Daily, Every other day, Every three days, Weekly, or Never. Default selection is Daily.
12.2 The choice is stored on the device (`quitcash.reminder.v1`). The user can change it in Settings (gear icon on the Bank screen).
12.3 Users who finished onboarding before this feature see a one-time prompt on the Bank screen.
12.4 Reminders go out at 7 pm local time (`reminderHour` in `lib/reminders/reminder_plan.dart`).
12.5 The app queues the next 14 reminders. It rebuilds the queue at each launch, each save and each change. The copy quotes the total dollars saved across all goals (one app-wide notification, not tied to whichever goal happens to be active).
12.6 The app asks for notification permission only when the user selects an option that is not Never.
12.7 Android: `POST_NOTIFICATIONS` (Android 13+) and `RECEIVE_BOOT_COMPLETED` are in the manifest. The app uses inexact alarms, so it does not need `SCHEDULE_EXACT_ALARM`.
12.8 Android: core library desugaring is on in `android/app/build.gradle.kts`. Do not remove it.
12.9 iOS/macOS: the app asks for alert, badge and sound permission.
12.10 Web and Linux/Windows: the app stores the choice and shows no notifications.
12.11 To test on a device, select Daily, then put the device clock forward past 7 pm.

## 13. Denominations and Settings

13.1 Denominations: $1 copper, $5 silver, $10 gold, $20 emerald, $50 sapphire, $100 ruby gem, $500 diamond gem.
13.2 Each denomination uses one `Metal` color ramp (light, base, deep, edge, outline). Coins, gem, sparkles, burst and flying coins use the same ramp.
13.3 The $100 is a cushion-cut ruby (`GemPainter`) and the $500 is a round brilliant diamond (`DiamondPainter`: icy white/blue facets, rainbow fire glints). `Denomination.cut` (`Cut.coin`, `Cut.cushion`, `Cut.brilliant`) selects the painter in `painterFor`. Both gems use the same tap, burst and fly-to-counter flow as the coins.
13.4 The top-bar counter icon is always the gold ($10) coin.
13.5 Settings has "Show $50", "Show $100" and "Show $500". All are OFF by default (opt-in). They are stored as `quitcash.flag.show50`, `quitcash.flag.show100` and `quitcash.flag.show500`.
13.6 Hidden denominations go out of the picker only. History, total and level do not change.
13.7 If the selected denomination becomes hidden, the picker selects the largest visible one below it.
13.8 Reset in Settings clears only the active goal's history (button: `Reset "<goal>" progress`). Other goals and settings do not change.

## 14. Goals

14.1 A goal is one habit being kicked or curbed (habit from the shared `HabitPicker`, optional label up to 30 characters, emoji from the habit). Each goal has its own savings history, total, level and badges.
14.2 Bank and Trophies show the active goal. Switch on the Goals tab (tap a goal; the active one has a gold border and an ACTIVE tag) or from Bank (tap the "by skipping ..." chip to open the quick switcher sheet).
14.3 Add a goal: Goals tab "Add a goal", or the switcher sheet. The new goal becomes active.
14.4 Delete a goal: trash icon, then a destructive confirm. If the active goal is deleted, the first remaining goal becomes active.
14.5 Deleting the last goal returns to onboarding. Global settings stay: the coin toggles and the reminder choice (onboarding preselects the saved choice, so the user can keep or change it).
14.6 Settings (coin toggles, reminders) are global, not per goal.
14.7 Storage: `quitcash.goals.v1` (JSON list), `quitcash.goal.active.v1`, `quitcash.goal.<id>.entries.v2` (clustered records, see 15).
14.8 Migration: single-goal data (`quitcash.habit.v1` + `quitcash.entries.v1`) becomes goal `g1`, active. The history string is copied verbatim, the goals list is written last (an interrupted migration re-runs), then the legacy keys are removed. Tested in `test/repository_test.dart`.

## 15. Tap clustering and History

15.1 Money is stored as integer cents (`SaveEntry.cents`). Each record has a stable `id`.
15.2 Taps join one record when each tap comes within the grouping window of the previous tap in the same goal (sliding window, inclusive). The record's time is the FIRST tap's time; its amount is the sum. A record never exceeds $9,999.99; a tap that would overflow starts a new record.
15.3 The window is a global setting: Settings > "Group taps within": 10s, 30s, 60s, 2 min, 5 min. Default 60s (`defaultTapWindow` in `lib/domain/models/tap_cluster.dart`). Stored as `quitcash.number.tapWindowSeconds`; unknown values fall back to 60s.
15.4 Switching, adding or deleting goals, Reset, and editing or deleting a record close the open cluster. A relaunch starts with no open cluster.
15.5 Each tap is written at once: the first tap appends a record, later taps update it in place. An app kill mid-cluster loses nothing.
15.6 Animations, level-ups and badge popups still fire per tap.
15.7 History: tap the dollar total in the top-left of Bank. It lists the active goal's records newest first, grouped by day (Today, Yesterday, date) with a day total, amount, time and a mini coin (largest denomination at or below the amount). Empty state when there are no records.
15.8 Edit: tap a record. Amount accepts cents (`8`, `8.5`, `8.50`), must be > $0 and <= $9,999.99 (`parseCents`). Date and time can be changed too. Delete asks for confirmation and shows an Undo snackbar.
15.9 Total, level and badges are always recomputed from history. An edit down or a delete can take back a level or a badge; nothing is kept separately.
15.10 Migration: per-tap history (`quitcash.goal.<id>.entries.v1`, also the target of the single-goal migration in 14.8) is clustered with the default 60s window into `entries.v2` on first load, then v1 is removed (v2 is written first, so an interrupted migration re-runs). The total is unchanged; old check-in rows are dropped as before.

## 16. Trends

16.1 Trends is its own tab (Bank, Goals, Trends, Trophies). It shows the active goal; with two or more goals a "This goal / All goals" toggle appears. Dollars only: no XP, streaks or coin currency.
16.2 Data source: history records (tap clusters, 15). Everything is recomputed from records on each rebuild, so edits and deletes show at once. Math lives in `lib/domain/models/trend_report.dart` and `trend_insights.dart` (pure, unit-tested).
16.3 Periods (local calendar days; calendar arithmetic, so DST days stay whole): Week = last 7 days incl. today, Month = last 30 days, Year = last 12 calendar months, All = months from the first record. The previous period is the window of the same length just before (none for All).
16.4 Hero ring: progress from the current level threshold to the next (all-time for the scope); the center shows the period total.
16.5 Chart: bars per day (Week, Month) or per month (Year, All), the highest bar in gold. The change chip shows % vs the previous period; with an empty previous period there is no % ("No savings in ...").
16.6 Stats: average per day (period total / days so far), best day (highest day total), biggest single save (largest record).
16.7 Patterns: dollars by weekday (bars) and records by hour (24-cell heat strip). "Most common craving time" = the 4-hour slot with the most records.
16.8 Projection: pace = cents per day over the last 30 days (or since the first record if shorter). Next milestone = next level threshold; date = today + remaining / pace (rounded up). Yearly = pace x 365. No date when the pace is 0.
16.9 Insights: 2–4 cards built only from the numbers above (change vs previous, craving time, strongest weekday, milestone pace). Under 3 records in the period: one friendly "Trends are warming up" card; patterns and projection show placeholder text.
16.10 Charts are `CustomPainter`s (no chart dependency), like the coin art. They animate in with `TweenAnimationBuilder`.
16.11 Demo data for screenshots only: `flutter build web --release -t tool/demo_main.dart -o build/web-demo` serves a seeded, in-memory app. It is not part of `lib/` and is never the default.


## 17. Change (cents) mode

17.1 Settings > Change (global, off by default, saved as flag `change`). When on, a pill above the Bank picker (`¢ Change` / `$ Dollars`) switches the picker between dollar coins and change coins. The last mode is saved (flag `changeMode`). When Change is off the pill is hidden and the picker is always dollars; the saved mode returns when it is turned on again.
17.2 Change coins live in `changeDenominations` (`lib/ui/core/themes/denominations.dart`) and are drawn by `ChangeCoinPainter` (`lib/ui/core/widgets/change_coin_painter.dart`): smaller (`scale`) and thinner than dollar coins, same outline, edge stack and glint. 1¢ round penny copper (redder and darker than the $1 copper), 5¢ matte nickel with a scalloped edge, 10¢ bright silver with a center hole, 25¢ octagonal silver ring with a brass center. Labels read `1¢`…`25¢`; the coins draw no text (goldens stay font-free).
17.3 All money is integer cents: `SavingsViewModel.addCents` (dollar taps go through it too). Change and dollar taps join the same history cluster within the window. Level and badge math already uses cents. A change tap flies one coin to the counter, which shows cents (`$0.10`).
17.4 Golden: `test/goldens/change_coins.png`. Frames: `flutter test tool/coin_frames_test.dart --dart-define=OUT=/tmp/f --dart-define=CENTS=25` (also writes `change-sheet.png`).
