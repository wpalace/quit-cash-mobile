import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/config.dart';
import 'services/local_savings_repository.dart';
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
  bool _inFlight = false;
  bool _loadError = false;
  bool _storageUnavailable = false;

  double get totalSaved => _totalSaved;
  bool get isLoading => _isLoading;

  /// D-14: launch total read failed (corrupt/locked DB). Renders `$0.00`
  /// (empty-state shape, APP-02) with a "Couldn't load your savings" warning
  /// SnackBar; coin taps remain enabled.
  bool get loadError => _loadError;

  /// D-15: local DB uncreateable/unopenable (storage full, read-only fs).
  /// Dedicated state: total hidden, coin taps disabled.
  bool get storageUnavailable => _storageUnavailable;

  SavingsModel({required SavingsRepository repository})
      : _repository = repository {
    _loadTotal();
  }

  /// Load the total from the repository — the single source of truth
  /// (D-04: always `SUM(amount)`, no cached value).
  Future<void> _loadTotal() async {
    _isLoading = true;
    notifyListeners();
    try {
      _totalSaved = await _repository.getTotal();
      _loadError = false;
    } catch (e) {
      // D-14: launch read failure -> render $0.00 with a warning; the total
      // is unchanged (0.00 at launch, previous value after a successful tap).
      print('Failed to load savings: $e');
      if (e is StorageUnavailableException) {
        _storageUnavailable = true;
      } else {
        _loadError = true;
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Record a savings of [amount] dollars; return whether it was applied.
  ///
  /// Returns [false] if the tap was ignored (a prior tap's write + re-query
  /// is still in flight, D-03) or the local write failed (D-13). Failed taps
  /// never block or corrupt subsequent taps — each tap is an independent
  /// write (D-16): the in-flight flag clears on completion, success or
  /// failure, so a failed tap never leaves the UI stuck.
  Future<bool> addSavings(double amount) async {
    if (_inFlight) {
      return false;
    }
    _inFlight = true;
    try {
      if (!amount.isFinite) {
        throw ArgumentError('Amount must be a number.');
      }
      if (amount < 0) {
        throw ArgumentError('Amount must not be negative.');
      }
      if (amount > 9999.0) {
        throw ArgumentError('Amount must not exceed 9999.00.');
      }
      await _repository.add(amount);
      await _loadTotal();
      return true;
    } catch (e) {
      // D-13: failed write -> print-log, leave the total unchanged, app
      // continues (matches the service-layer try/catch convention).
      print('Failed to add savings: $e');
      if (e is StorageUnavailableException) {
        _storageUnavailable = true;
        notifyListeners();
      }
      return false;
    } finally {
      _inFlight = false;
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loadErrorSnackBarShown = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<SavingsModel>(
      builder: (context, savings, _) {
        // D-14: one-time "Couldn't load your savings" warning for a failed
        // launch total read (taps stay enabled).
        if (savings.loadError && !_loadErrorSnackBarShown) {
          _loadErrorSnackBarShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Couldn't load your savings"),
                backgroundColor: Colors.red,
              ),
            );
          });
        }
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
                  child: savings.storageUnavailable
                      ? _storageUnavailableMessage()
                      : _totalArea(context, savings.totalSaved),
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
                    children: [
                      CoinButton(
                        amount: 1.0,
                        color: Colors.brown,
                        enabled: !savings.storageUnavailable,
                      ),
                      CoinButton(
                        amount: 5.0,
                        color: Colors.blueGrey,
                        enabled: !savings.storageUnavailable,
                      ),
                      CoinButton(
                        amount: 10.0,
                        color: Colors.orange,
                        enabled: !savings.storageUnavailable,
                      ),
                      CoinButton(
                        amount: 20.0,
                        color: Colors.green,
                        enabled: !savings.storageUnavailable,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// D-15: dedicated state when the local DB cannot be created/opened —
  /// total hidden, coin taps disabled.
  Widget _storageUnavailableMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning,
            size: 72,
            color: Color(0xFFB71C1C),
          ),
          const SizedBox(height: 16),
          const Text(
            'Storage unavailable',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "We can't open your savings file. Coin taps are disabled.",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Total area — always re-derived from `SUM(amount)` (D-01/D-02).
  Widget _totalArea(BuildContext context, double totalSaved) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Total Saved',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          '\$${totalSaved.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: Colors.green.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class CoinButton extends StatelessWidget {
  final double amount;
  final Color color;

  /// When false (D-15), the button is visually muted and taps are ignored;
  /// the storage-unavailable state disables all coin taps.
  final bool enabled;

  const CoinButton({
    super.key,
    required this.amount,
    required this.color,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final Widget button = GestureDetector(
      onTap: () async {
        if (!enabled) {
          return;
        }
        final model = Provider.of<SavingsModel>(context, listen: false);
        final amountText = '\$${amount.toStringAsFixed(0)}';
        try {
          final applied = await model.addSavings(amount);
          if (!context.mounted) {
            return;
          }
          _showSnackBar(
            context,
            applied
                ? 'Saved $amountText!'
                : "Couldn't save $amountText",
          );
        } catch (e) {
          if (context.mounted) {
            _showSnackBar(context, "Couldn't save $amountText");
          }
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
    return enabled ? button : Opacity(opacity: 0.35, child: button);
  }

  /// D-13 UX: on a failed local write the model print-logs the error and
  /// leaves the total unchanged; the button shows "Couldn't save `$amount`" and
  /// the app continues (D-16: a failed tap never blocks the next tap).
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }
}

