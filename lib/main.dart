import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/data/repositories/prefs_savings_repository.dart';
import 'package:quit_cash_mobile/data/repositories/savings_repository.dart';
import 'package:quit_cash_mobile/data/services/reminder_service.dart';
import 'package:quit_cash_mobile/ui/app/quit_cash_app.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';

/// Launch build is client-side only: all data stays on the device.
/// To add a backend later, implement [SavingsRepository] and swap it here.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final SavingsRepository repository = PrefsSavingsRepository();
  runApp(
    ChangeNotifierProvider(
      create: (_) => SavingsViewModel(
        repository: repository,
        reminders: platformReminderService(),
      ),
      child: const QuitCashApp(),
    ),
  );
}
