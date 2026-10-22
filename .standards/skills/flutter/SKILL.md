---
name: flutter
description: "House coding standard for Flutter 3.47 / Dart 3.13. Use when writing, editing, or reviewing Flutter or Dart code (*.dart, pubspec.yaml, analysis_options.yaml)."
---

# Flutter / Dart Standards

> **Before calling work done:** run the formatter and linter checks in the Formatting section (`dart format --output=none --set-exit-if-changed . && flutter analyze --fatal-infos && flutter test`) and fix every finding. Reference config: `analysis_options.yaml` beside this file, which `sync-standards.sh` installs at the project root.

**Targets:** Flutter 3.47 stable with Dart 3.13 (both released Aug 12, 2026; test-driven on 3.47.7 / Dart 3.13.5). Set `environment: sdk: ^3.13.0` for new apps. Existing apps may stay on Dart 3.10+ until they migrate.

We follow Effective Dart and the official Flutter architecture guide. Tools make the style calls so review can focus on behavior.

## Project Layout

- Organize the UI **by feature** and shared data **by type**, following the official guide: `lib/ui/<feature>/` holds the view and view model; `lib/data/repositories/` and `lib/data/services/` hold the data layer. `lib/domain/` holds immutable models.
- **Views** are widgets that know exactly one view model. **View models** hold UI state and expose commands. **Repositories** are the source of truth and own caching, retries, and mapping. **Services** wrap one external API or plugin and hold no state.
- Data flows one way: repository → view model → view. User events go back through view model methods.
- Add a domain (use-case) layer only when logic is repeated or crowds the view models.

```text
lib/
  ui/checkout/{checkout_screen.dart, checkout_view_model.dart, widgets/}
  data/repositories/order_repository.dart
  data/services/payments_api.dart
  domain/models/order.dart
```

## Naming

- `UpperCamelCase` for types, enums, extensions, and typedefs. `lowerCamelCase` for members, variables, and constants. Use `snake_case.dart` for files, directories, and import prefixes.
- Add a suffix for the role: `CheckoutScreen`, `CheckoutViewModel`, `OrderRepository`, `PaymentsApi`.
- Use `_private` for library-private names. Don't use `I` prefixes or Hungarian notation.

## Formatting

Code is formatted for human readability and review.

- Use **`dart format`** with the tall style (Dart 3.7+). The formatter now **adds and removes trailing commas itself**, so don't fight it. Dart 3.13 also puts blank lines between import groups (dart, package, relative) but does **not** sort them, so enable the `directives_ordering` lint.
- Keep the default page width of **80**. Change it only in `analysis_options.yaml` (`formatter: page_width:`), never per run.
- Use `const` constructors wherever they're allowed. One public widget per file, named after the file.
- Keep `build` methods short, about 40 lines at most. Extract subtrees into widgets once nesting goes past four or five levels.
- CI runs `dart format --output=none --set-exit-if-changed .` and `flutter analyze`. Don't mix reformatting with logic changes in one PR.

```dart
// Formatter output: one argument per line once the call splits.
return OrderTile(
  order: order,
  onTap: () => viewModel.open.execute(order.id),
);
```

## Lints

- Every project has an `analysis_options.yaml` that includes **`flutter_lints`** (6.x). Teams that want stricter rules may use **`very_good_analysis`** instead. Pick one per repo.
- Turn on `strict-inference`. On Dart 3.13+, use the new `no_dynamic_casts` and `no_raw_types` lints, which supersede `strict-casts` and `strict-raw-types`. The old flags still work (no deprecation warning in 3.13.5) and report errors instead of infos, but don't enable both. Older SDKs keep the flags.
- `no_dynamic_casts` flags only *implicit* casts from `dynamic`; explicit `as` casts pass, so reviewers still check them.
- Also enable `avoid_print`, `unawaited_futures`, `use_build_context_synchronously`, `prefer_const_constructors`, and `directives_ordering`. The draft config raises `unawaited_futures` and `use_build_context_synchronously` to errors.

## Widgets & State

- Prefer `StatelessWidget`. Use `StatefulWidget` only for state local to the widget, such as controllers and animations, and dispose of what you create.
- **Extract widgets, not helper methods** that return `Widget`. Extracted widgets rebuild on their own and can be `const`.
- Use `ValueKey` for list items that are reordered or removed, and `GlobalKey` only when you truly need it.
- Choose **one** state approach per app. The default is `ChangeNotifier` view models with `provider` for dependency injection, as the official guide does. Riverpod is fine if the whole app uses it. Never mix the two.
- No business logic in widgets. Views may only show or hide based on state, run animations, adapt layout, and route.

## Async & Errors

- Use `async`/`await`. Mark intentional fire-and-forget calls with `unawaited()`.
- Never create the future inside `FutureBuilder.future`. Create it in `initState` or the view model.
- After any `await`, check `if (!context.mounted) return;` before using `BuildContext`.
- Repositories return a sealed `Result<T>` (`Ok`/`Error`) instead of throwing across layers. View models turn errors into UI state.
- Never swallow errors. Report them through `FlutterError.onError` and `PlatformDispatcher.instance.onError` to your crash reporter.

```dart
sealed class Result<T> { const Result(); }
final class Ok<T> extends Result<T> { const Ok(this.value); final T value; }
final class Error<T> extends Result<T> { const Error(this.error); final Exception error; }
```

## Null Safety & Modern Dart

- Null safety is sound and required. Use `!` only with a comment explaining why the value can't be null.
- Use **records** for small multi-value returns, and **patterns** and `switch` expressions for exhaustive branching.
- Use **sealed classes** for view states (`Loading`, `Loaded`, `Failed`) so the compiler checks every case.
- Use **extension types** for zero-cost IDs (`extension type OrderId(String value)`).
- **Dot shorthands** (3.10+) are allowed where the type is obvious: `mainAxisAlignment: .center`.
- **Primary constructors** (3.13+) are encouraged for simple data classes: `class Point(final int x, final int y);`.
- Macros were cancelled. Use `build_runner` with `freezed` or `json_serializable` for code generation. Each repo states whether generated files are committed.

## Dependencies

- Use caret constraints (`^1.4.0`). Commit `pubspec.lock` for apps but not for published packages.
- Run `flutter pub outdated` monthly and upgrade in a dedicated PR. Every new package needs a reason in the PR description.
- Use **pub workspaces** (`workspace:` with globs, Dart 3.11+) for monorepos instead of path overrides.

## Testing

- Write unit tests for view models and repositories, using fakes. Mock with **`mocktail`**; no code generation needed.
- Write widget tests for every screen, and golden tests for key components (with fonts pinned).
- Put end-to-end flows in `integration_test/`, and run them in CI on at least one platform.

## Platform & Security

- No secrets in code, assets, or `--dart-define`. Anything shipped in the app is public. Use `--dart-define-from-file=env/prod.json` (git-ignored) for configuration only, and keep secrets on the backend.
- Release builds use `--obfuscate --split-debug-info=build/symbols`, and the symbols get uploaded.
- Use flavors (`--flavor dev|prod`) for each environment, each with its own app ID.

## Exceptions

Every exception is narrow, needs a written justification next to the code or config it affects, and should be listed under "Declared exceptions" in the project's `AGENTS.md`. Everything else in this standard still applies.

- **Single-line ignores.** `// ignore: <lint> - <reason>` on one line is allowed. `ignore_for_file` is allowed only for generated files.
- **CLI tools.** `print` is allowed in CLI tools under `tool/`.
- **Older Dart.** Existing apps below Dart 3.13 may keep `strict-casts` and `strict-raw-types` until they upgrade. Don't enable them together with `no_dynamic_casts` / `no_raw_types`.
- **Frozen files.** Files that feed a build or image fingerprint (any byte change invalidates it) may be listed in the project's `.standards-exclude`, one path or glob per line with a required `# reason`. CI and pre-commit then skip them for `dart format`. `flutter analyze` has no command-line exclude, so a project with frozen Dart files owns its root `analysis_options.yaml`: it holds `include: .standards/skills/flutter/analysis_options.yaml` and lists the same paths under `analyzer: exclude:` (the lists merge). Keep the list short and review it like code.

## Avoid

- `setState` high in large trees, and passing `BuildContext` across async gaps without a `mounted` check.
- `dynamic` and untyped `Map<String, dynamic>` past the service boundary.
- `print` instead of `package:logging` or `dart:developer` `log`.
- Deep widget nesting, and `late` used to dodge initialization (use nullable or `required` instead).
- Ignoring lints file-wide, or `catch (_) {}`.

## Sources

- Flutter Blog, "What's new in Flutter 3.47" (Emma Twersky, Aug 12, 2026)
- Dart Blog, "Announcing Dart 3.13" (Connie Ooi, Aug 12, 2026); dart.dev changelog
- docs.flutter.dev, "Guide to app architecture" and "Architecture recommendations"
- Nicolas, "Flutter 3.47 and Dart 3.13: What Actually Changed" (Medium, Aug 2026; members-only, preview only)
