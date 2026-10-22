import 'dart:developer' as developer;
import 'dart:ui';

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
  _installErrorReporting();
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

/// Routes uncaught framework and platform errors to the log. There is no
/// crash reporter yet (client-only launch, zero infra): see AGENTS.md,
/// Declared exceptions. Swap [_report] for a reporter when one is added.
void _installErrorReporting() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    _report(details.exception, details.stack);
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _report(error, stack);
    return true;
  };
}

void _report(Object error, StackTrace? stack) => developer.log(
  'uncaught error',
  name: 'quitcash',
  error: error,
  stackTrace: stack,
);
