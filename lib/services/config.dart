// lib/services/config.dart
//
// Compile-time build configuration selected via `--dart-define CONFIG=local|cloud`.
//
// Flutter injects a top-level `const String CONFIG` when the build flag is
// passed. [AppConfig.fromDefine] resolves that const to [AppConfig.local] or
// [AppConfig.cloud]. Resolution rules (D-09 / D-10 / D-11):
//
//   * "local" (or "" ) -> [AppConfig.local]   (the default)
//   * "cloud"          -> [AppConfig.cloud]
//   * anything else    -> fail-fast (ArgumentError)
//
// Tree-shaking (D-10): [repositoryFor] keys off a compile-time constant, so the
// branch that is not taken for a given build is eliminated from the binary. The
// local build therefore contains no cloud code path (LOC-03).
//
// NOTE on `flutter test`: `flutter test` does *not* inject `--dart-define` consts,
// so the top-level `CONFIG` is undefined under tests. This file is therefore
// deliberately only reachable from the app entrypoint (`main.dart`) and is never
// imported by unit tests. The testable pure seam is [AppConfig.fromDefine].

import 'cloud_savings_repository.dart';
import 'local_savings_repository.dart';
import 'savings_repository.dart';

/// Build-time configuration of the app.
class AppConfig {
  const AppConfig._this(this._isCloud);

  final bool _isCloud;

  bool get isLocal => !_isCloud;
  bool get isCloud => _isCloud;

  /// Local-only persistence. The default build configuration.
  static const AppConfig local = AppConfig._this(false);

  /// Cloud persistence (Phase 2).
  static const AppConfig cloud = AppConfig._this(true);

  /// Resolve the raw `CONFIG` build-flag string to an [AppConfig].
  ///
  /// [raw] is expected to be the value of the top-level `CONFIG` const.
  /// This is a pure function and is unit-testable without the build flag.
  static AppConfig fromDefine(String raw) {
    switch (raw.toLowerCase()) {
      case 'local':
        return local;
      case '':
        // D-09: empty / unspecified -> default to local.
        return local;
      case 'cloud':
        return cloud;
      default:
        // D-10: fail fast on unknown / typoed values; never fall through to
        // local.
        throw ArgumentError(
          'Unknown CONFIG value "$raw". Expected "local" or "cloud".',
        );
    }
  }
}

/// Build-time repository seam (D-10). [appConfig] is a compile-time constant
/// (it comes from [AppConfig.fromDefine(CONFIG)]), so the compiler eliminates
/// the branch that is not taken: the local binary contains no cloud code and
/// vice versa.
SavingsRepository repositoryFor(AppConfig appConfig) {
  if (appConfig.isCloud) {
    return CloudSavingsRepository();
  }
  return LocalSavingsRepository();
}
