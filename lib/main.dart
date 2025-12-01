import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
// import 'package:opentelemetry/api.dart'; // Uncomment when OTel is fully configured

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => SavingsModel(),
      child: const QuitCashApp(),
    ),
  );
}

class SavingsModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  double _totalSaved = 0.0;
  bool _isLoading = false;

  double get totalSaved => _totalSaved;
  bool get isLoading => _isLoading;

  SavingsModel() {
    _loadTotal();
  }

  Future<void> _loadTotal() async {
    _isLoading = true;
    notifyListeners();
    _totalSaved = await _apiService.getTotalSavings();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addSavings(double amount) async {
    try {
      await _apiService.addSaving(amount);
      await _loadTotal(); // Refresh total from server
    } catch (e) {
      print('Failed to add savings: $e');
      // Optimistic update could go here, but keeping it simple for now
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
        fontFamily: 'Roboto', // Default, but good to be explicit
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
      onTap: () {
        Provider.of<SavingsModel>(context, listen: false).addSavings(amount);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved \$${amount.toStringAsFixed(0)}!'),
            duration: const Duration(milliseconds: 500),
          ),
        );
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
