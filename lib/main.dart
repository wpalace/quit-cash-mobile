import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/prefs_savings_repository.dart';
import 'data/savings_repository.dart';
import 'reminders/reminder_service.dart';
import 'state/savings_model.dart';
import 'ui/app.dart';

/// Launch build is client-side only: all data stays on the device.
/// To add a backend later, implement [SavingsRepository] and swap it here.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final SavingsRepository repository = PrefsSavingsRepository();
  runApp(
    ChangeNotifierProvider(
      create: (_) => SavingsModel(
        repository: repository,
        reminders: platformReminderService(),
      ),
      child: const QuitCashApp(),
    ),
  );
}
