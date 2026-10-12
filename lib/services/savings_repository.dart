// lib/services/savings_repository.dart
//
// Persistence seam. The app depends on this interface only; the concrete
// implementation is selected at build time by [AppConfig] via the
// `--dart-define CONFIG` seam (see lib/services/config.dart).
//
/// Amounts at the seam boundary are in **dollars** (`double`).
///
/// - The local implementation ([LocalSavingsRepository]) converts to integer
///   cents on the way into SQLite (D-05) and back to dollars for [getTotal].
/// - The cloud implementation (Phase 2, [CloudSavingsRepository]) will take
///   dollars directly from the API.
///
/// This file is deliberately free of the build-flag const so it (and the local
/// repository, and unit tests that exercise it) compile under `flutter test`,
/// which does not inject `--dart-define` consts.
abstract class SavingsRepository {
  /// Record a savings of [amount] dollars.
  ///
  /// [amount] must be non-negative; a negative or non-finite value is rejected
  /// (D-04 / D-09 input validation at the seam).
  Future<void> add(double amount);

  /// Total saved, in dollars: the sum of all recorded amounts (D-04).
  Future<double> getTotal();

  /// Remove all savings (user reset, D-08).
  Future<void> clear();
}
