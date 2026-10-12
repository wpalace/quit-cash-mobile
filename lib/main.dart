import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/config.dart';
import 'services/savings_repository.dart';

/// Build flag read from `--dart-define CONFIG` (D-09).
///
/// Flutter does *not* inject a top-level identifier for `--dart-define` — the
/// flag value is a compile-time constant read with [String.fromEnvironment].
///   * local build (default): no flag, or `flutter run --dart-define CONFIG=local`
///   * cloud build (Phase 2):  `flutter run --dart-define CONFIG=cloud`
/// Missing flag (or empty value) defaults to local (D-09); an unknown/typoed
/// value throws (fail-fast, D-10) so the local binary can never silently fall
/// through to cloud and vice versa.
const String kConfig = String.fromEnvironment('CONFIG', defaultValue: 'local');

/// Wire the app to the matching persistence path (D-09/D-10, LOC-03).
///
/// [AppConfig.fromDefine] is the pure, unit-testable seam. The keyword set
/// below is mirrored as **const local variables** over const string equality
/// (Dart has no const functions); [appConfig] constant-folds to
/// [AppConfig.local] or [AppConfig.cloud] at build time, so [repositoryFor]
/// branches on a compile-time-known [AppConfig] and AOT eliminates the
/// unused branch from the binary (D-10).
void main() {
  const bool _isLocal =
      kConfig == 'local' || kConfig == 'LOCAL' || kConfig == '';
  const bool _isCloud = kConfig == 'cloud' || kConfig == 'CLOUD';

  if (!_isLocal && !_isCloud) {
    // D-10: fail-fast on unknown / typoed values; never fall through to local.
    // (Const expressions cannot throw, so this is a launch-time fail-fast.)
    throw ArgumentError(
      'Unknown CONFIG value "$kConfig". Expected "local" or "cloud".',
    );
  }

  const AppConfig appConfig = _isCloud ? AppConfig.cloud : AppConfig.local;
  final SavingsRepository repository = repositoryFor(appConfig);
  runApp(
    ChangeNotifierProvider(
      create: (context) => SavingsModel(repository: repository),
      child: const QuitCashApp(),
    ),
  );
}

/// App-level model. Depends only on the [SavingsRepository] seam; the local
/// path (Phase 1) is [LocalSavingsRepository] and the cloud path (Phase 2)
/// will be [CloudSavingsRepository]. No cloud dependency here for the local
/// build.
class SavingsModel extends ChangeNotifier {
  final SavingsRepository _repository;
  double _totalSaved = 0.0;
  bool _isLoading = false;

  double get totalSaved => _totalSaved;
  bool get isLoading => _isLoading;

  SavingsModel({required SavingsRepository repository})
      : _repository = repository {
    _loadTotal();
  }

  /// Load the total from the repository — the single source of truth
  /// (D-04: always `SUM(amount)`, no cached value).
  Future<void> _loadTotal() async {
    _isLoading = true;
    notifyListeners();
    _totalSaved = await _repository.getTotal();
    _isLoading = false;
    notifyListeners();
  }

  /// Record a savings of [amount] dollars. Validates at the app boundary
  /// (D-09): finite, non-negative, <= $9999.00. Non-numeric / empty input is
  /// rejected where the user enters a value (the coin buttons here are fixed
  /// and valid; a text-entry UI lands in Phase 3).
  Future<void> addSavings(double amount) async {
    if (!amount.isFinite) {
      throw ArgumentError('Amount must be a number.');
    }
    if (amount < 0) {
      throw ArgumentError('Amount must not be negative.');
    }
    if (amount > 9999.0) {
      throw ArgumentError('Amount must not exceed 9999.00.');
    }
    try {
      await _repository.add(amount);
      await _loadTotal();
    } catch (e) {
      throw ArgumentError('Failed to add savings: $e');
    }
  }
}

class QuitCashApp extends StatelessWidget {
  const QuitCashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuitCash',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SetupPage(),
    );
  }
}

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.savings, size: 100, color: Colors.amber),
            const SizedBox(height: 20),
            Text(
              'QuitCash',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade900,
              ),
            ),
            const SizedBox(height: 10),
            const Text('Turn bad habits into cash!'),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Saving', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Savings'),
        backgroundColor: Colors.amber,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Center(
              child: Consumer<SavingsModel>(
                builder: (context, savings, child) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Total Saved',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '\$${savings.totalSaved.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: const [
                  CoinButton(amount: 1.0, color: Colors.brown),
                  CoinButton(amount: 5.0, color: Colors.blueGrey),
                  CoinButton(amount: 10.0, color: Colors.orange),
                  CoinButton(amount: 20.0, color: Colors.green),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CoinButton extends StatelessWidget {
  final double amount;
  final Color color;

  const CoinButton({super.key, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final model = Provider.of<SavingsModel>(context, listen: false);
        try {
          await model.addSavings(amount);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved \$${amount.toStringAsFixed(0)}!'),
              duration: const Duration(milliseconds: 500),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              duration: const Duration(milliseconds: 500),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '\$${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
