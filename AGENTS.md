# AGENTS.md

Instructions for every AI coding agent working in this repository (Cursor, Claude Code, Copilot, Codex, Grok, and others).

## Coding standards

This project follows the house coding standards, vendored at `.standards/` (pinned in `.standards-version`). Languages used here:

- flutter: `.standards/skills/flutter/SKILL.md`

## Rules

1. **Load the matching skill before editing.** Before you create or change a file in one of these languages, read its `SKILL.md` above and follow it. If a file mixes languages (for example a Dockerfile that runs a shell script), load each skill involved.
2. **Run the checks before declaring done.** Run the format and lint commands from the skill's Formatting section (or `pre-commit run --all-files`) and fix every finding. Never say a task is complete while a check fails. If a check cannot run here, say so explicitly.
3. **Keep reformatting and logic changes in separate commits.** Commit formatter-only changes on their own first, then the behavior change.
4. **Don't edit `.standards/` or managed configs** (`ruff.toml`, `.tflint.hcl`, `.hadolint.yaml`, `.yamllint.yaml`, `PSScriptAnalyzerSettings.psd1`, `analysis_options.yaml` when it carries the managed header, or the managed block in `.editorconfig`). They are overwritten by `.standards/scripts/sync-standards.sh`. Propose changes upstream in the standards repo instead.
5. **Exceptions must be declared.** Use only the exceptions listed in a skill's Exceptions section. Each one needs a justification comment at the code or config it affects and an entry under "Declared exceptions" below. Files in `.standards-exclude` are frozen, so don't edit or reformat them.
6. **Project rules win on conflict.** Anything in the project-specific section below overrides the shared standard.

## Running the project

`MAKE.md` is the entry point for building, testing, and running this project. Read it before running commands, and use the commands it documents rather than guessing.

## Declared exceptions

- Flutter: root `analysis_options.yaml` is project-owned (no managed header). It includes `.standards/skills/flutter/analysis_options.yaml` unchanged and only adds stricter rules (`prefer_final_locals`, `sort_child_properties_last`). Reason: keep extra project rules without editing the managed file. `.standards-exclude` is empty (no frozen or generated Dart files).
- Flutter: one app-wide `SavingsViewModel` is shared by all screens instead of one view model per view. Reason: small app where every screen reads the same goals, active-goal progress and settings state (Goals, Bank, Trophies and Settings all react to the active goal); split per feature when screens gain their own state.
- Flutter: view state uses `isLoading` / `loadError` flags, not a sealed `Loading/Loaded/Failed` class. Reason: load failure still renders the normal UI with an empty history; revisit with the per-feature view model split.
- Flutter: no crash reporter. `main.dart` routes `FlutterError.onError` and `PlatformDispatcher.instance.onError` to `dart:developer` `log`. Reason: client-only launch with zero infrastructure; replace `_report` when a reporter is chosen. Release symbols from `--split-debug-info` are kept locally, not uploaded.
- Flutter: no flavors and a single placeholder app ID (`com.example.quit_cash_mobile`). Reason: one environment (no backend) at launch; add `dev`/`prod` flavors with real IDs before store submission.
- Flutter: `HomeScreen` state `build` (~50 lines) and `CoinBurst.build` (~43 lines) are slightly over the ~40-line guide. Reason: they are a flat list of already-extracted widgets plus the effects overlay; splitting further adds indirection only.
- Flutter: tests use hand-written fakes (`InMemorySavingsRepository`, `FakeReminders`), not `mocktail`. Reason: fakes are simpler and fully cover the interfaces.
- Flutter: the denominations golden draws no text, so no fonts are pinned.

## Project-specific notes

- Standards are synced from `https://github.com/wpalace/coding-standards.git` (confirmed remote, 2026-10-21). The initial v1.2.0 sync used a local clone of that repo via `STANDARDS_SOURCE`; normal syncs need no override.
- Charts (Trends) are hand-written `CustomPainter`s instead of a chart package: no new dependency, same approach as the coin painters.
- `MAKE.md` is the entry point. All checks: `dart format --output=none --set-exit-if-changed . && flutter analyze --fatal-infos && flutter test`.
- End-to-end test: `integration_test/` runs on web with `flutter drive` and a matching `chromedriver` (see MAKE.md 4.6).
