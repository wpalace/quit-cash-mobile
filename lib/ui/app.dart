import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/savings_model.dart';
import 'palette.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/trophies_screen.dart';
import 'widgets/backdrop.dart';
import 'widgets/spinning_coin.dart';

class QuitCashApp extends StatelessWidget {
  const QuitCashApp({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuitCash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.gold,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Palette.skyTop,
      ),
      home: _Root(initialTab: initialTab),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root({required this.initialTab});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SavingsModel>();
    if (model.isLoading) {
      return const Scaffold(
        body: Backdrop(child: Center(child: SpinningCoin(size: 120))),
      );
    }
    if (model.habit == null) return const OnboardingScreen();
    return _Shell(initialTab: initialTab);
  }
}

class _Shell extends StatefulWidget {
  const _Shell({required this.initialTab});
  final int initialTab;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        child: IndexedStack(
          index: _tab,
          children: const [HomeScreen(), TrophiesScreen()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Palette.skyTop,
        indicatorColor: Palette.gold,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings, color: Palette.outline),
            label: 'Bank',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events, color: Palette.outline),
            label: 'Trophies',
          ),
        ],
      ),
    );
  }
}
