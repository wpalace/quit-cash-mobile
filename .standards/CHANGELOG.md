# Changelog

All notable changes to the coding standards are recorded here. This project uses [Semantic Versioning](https://semver.org/):

- **MAJOR:** a rule change that makes existing compliant code fail checks (new lint rule at error level, a formatter setting change, a stricter version target).
- **MINOR:** new guidance, a new language skill, or new optional checks that don't break compliant code.
- **PATCH:** wording fixes, examples, and documentation.

## [1.2.0] - 2026-10-21

### Added

- `skills/flutter/`: Flutter 3.47 / Dart 3.13 standard (test-driven on 3.47.7 / Dart 3.13.5), with `analysis_options.yaml` (flutter_lints, `strict-inference`, `no_dynamic_casts`, `no_raw_types`, `directives_ordering`, `page_width: 80`) and an `.editorconfig` fragment. Exceptions cover single-line ignores, `print` in `tool/`, older Dart, and frozen files.
- `sync-standards.sh`: detects Flutter/Dart from `pubspec.yaml` and installs `analysis_options.yaml` under the usual managed-marker rules (project-owned files are left alone unless `STANDARDS_FORCE=1`).
- `standards-check.yml`: `flutter` job (`subosito/flutter-action@v2.23.0`, Flutter 3.47.x) running `dart format --output=none --set-exit-if-changed` (skipping `.standards-exclude`), `flutter analyze --fatal-infos`, and `flutter test`, and failing if the analyzer migrated `analysis_options.yaml`.
- `.pre-commit-config.yaml`: local `dart format` and `flutter analyze` hooks, plus `flutter test` on pre-push.
- `AGENTS.md.template`: `analysis_options.yaml` listed as a managed config, with a Flutter example under "Declared exceptions".

### Notes

- Flutter 3.47 rewrites a root `analysis_options.yaml` on first `flutter analyze` to exclude `build/` and the platform directories. The managed file already lists them, so it stays byte-stable.

## [1.1.0] - 2026-10-21

Changes recommended while conforming the SQL AG lab (wpalace/SQLDockurLab#4). Default rules are unchanged; new exceptions are narrow and need a written justification.

### Fixed

- `Test-PowerShellStandard.ps1` analyzes each file on its own and retries the PSScriptAnalyzer 1.25 `UseCorrectCasing` crash, and the "Get-Command is not recognized" error that can follow it, up to `-MaxAttempts` (default 10). It fails loudly if every attempt crashes; findings are never dropped.
- `Test-PowerShellStandard.ps1` takes the file path first (position 0) and the settings path second (position 1). CI and pre-commit pass `-SettingsPath` by name.
- `sync-standards.sh` requires `STANDARDS_REPO` to be a remote URL and rejects local paths. New `STANDARDS_SOURCE` fetches from a local clone without recording it. `.standards/SOURCE` now records the commit.

### Added

- Exceptions sections in every skill:
  - PowerShell: Windows PowerShell 5.1 hosts, `Write-Host` in logging helpers, and a local native exit-code policy.
  - Bash: dispatch and entrypoint scripts.
  - Python: project-chosen target version.
  - Docker: root or device access with minimal capabilities.
  - Terraform: lab and single-operator projects.
  - Frozen files, in every skill except Terraform.
- `PSScriptAnalyzerSettings.Compat51.psd1`, applied automatically to files that declare `#Requires -Version 5.1`.
- `.standards-exclude`, a frozen-file list with a required reason per entry, and `scripts/list-standards-excludes.sh`. CI skips the listed files.
- A "Declared exceptions" section in the AGENTS.md template.

### Changed

- The shared `ruff.toml` no longer sets `target-version`. Ruff infers it from `requires-python`, so the two always match. 3.14 stays the default for new projects.
- The Python and Docker checks in `standards-check.yml` run ruff and hadolint directly (pinned versions) so they can honor `.standards-exclude`.

## [1.0.0] - 2026-10-17

### Added

- Skills for Python 3.14+, C# 14 / .NET 10, Bash 5.x, PowerShell 7.6, Docker and Compose v5, and Terraform 1.16.
- Reference configs: `ruff.toml`, `.editorconfig` fragments, `PSScriptAnalyzerSettings.psd1`, `.tflint.hcl`, `.hadolint.yaml`, `.yamllint.yaml`.
- `scripts/sync-standards.sh`, agent pointer templates, CI workflow templates, and a pre-commit template.
