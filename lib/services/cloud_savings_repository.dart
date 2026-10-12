// lib/services/cloud_savings_repository.dart
//
// Placeholder cloud persistence stub.
//
// Present in the source tree so the [repositoryFor] seam is complete and the
// cloud code path is a distinct, tree-shakeable branch (D-10). The real cloud
// implementation (API + auth + money, Phase 2) lands later. Until then the
// cloud build has no functional persistence; this stub documents the contract
// and fails loudly if the cloud path is ever exercised.

import 'savings_repository.dart';

class CloudSavingsRepository extends SavingsRepository {
  CloudSavingsRepository();

  @override
  Future<void> add(double amount) async {
    throw UnimplementedError('Cloud persistence lands in Phase 2 (API + auth + money).');
  }

  @override
  Future<double> getTotal() async {
    throw UnimplementedError('Cloud persistence lands in Phase 2 (API + auth + money).');
  }

  @override
  Future<void> clear() async {
    throw UnimplementedError('Cloud persistence lands in Phase 2 (API + auth + money).');
  }
}
