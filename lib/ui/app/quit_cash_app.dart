import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/ui/core/widgets/backdrop.dart';
import 'package:quit_cash_mobile/ui/core/widgets/spinning_coin.dart';
import 'package:quit_cash_mobile/ui/goals/goals_screen.dart';
import 'package:quit_cash_mobile/ui/home/home_screen.dart';
import 'package:quit_cash_mobile/ui/onboarding/onboarding_screen.dart';
import 'package:quit_cash_mobile/ui/trophies/trophies_screen.dart';

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
    final model = context.watch<SavingsViewModel>();
    if (model.isLoading) {
      return const Scaffold(
        body: Backdrop(child: Center(child: SpinningCoin(size: 120))),
      );
    }
    // No goals (first install, or every goal deleted): onboarding.
    if (model.activeGoal == null) return const OnboardingScreen();
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
          children: const [HomeScreen(), GoalsScreen(), TrophiesScreen()],
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
            key: Key('tab-goals'),
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag, color: Palette.outline),
            label: 'Goals',
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
