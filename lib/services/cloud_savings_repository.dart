// lib/services/cloud_savings_repository.dart
//
// Cloud persistence branch (Phase 2). Reached only when the app is built with
// `--dart-define CONFIG=cloud`; tree-shaken out of the local AOT binary (D-10).
//
// The cloud code path (this class + [ApiService] + the base-URL / dev-target
// logic) is deliberately isolated so the local build contains no cloud/API
// code path (LOC-03 / D-10). Phase 2 (02-01..02-03) makes it work end-to-end
// against the real API and hardens it (secrets, exposure).

import 'api_service.dart';
import 'savings_repository.dart';

class CloudSavingsRepository extends SavingsRepository {
  final ApiService _apiService = ApiService();

  @override
  Future<void> add(double amount) => _apiService.addSaving(amount);

  @override
  Future<double> getTotal() => _apiService.getTotalSavings();

  @override
  Future<void> clear() {
    // Cloud bulk-reset is a Phase 2 API surface; the local reset uses the local
    // repository. (D-08)
    throw UnimplementedError(
        'Cloud bulk-delete lands in Phase 2 (API + auth + money).');
  }
}
