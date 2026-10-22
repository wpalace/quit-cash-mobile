import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/utils/money.dart';

/// Edit one record: amount (validated, cents allowed), date and time, or
/// delete (with confirm and an Undo snackbar).
Future<void> showEditEntryDialog(BuildContext context, SaveEntry entry) {
  final model = context.read<SavingsViewModel>();
  final messenger = ScaffoldMessenger.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: model,
      child: _EditDialog(entry: entry, messenger: messenger),
    ),
  );
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.entry, required this.messenger});
  final SaveEntry entry;
  final ScaffoldMessengerState messenger;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _amount = TextEditingController(
    text: (widget.entry.cents / 100).toStringAsFixed(2),
  );
  late DateTime _at = widget.entry.at;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (!mounted) return;
    final t = time ?? TimeOfDay.fromDateTime(_at);
    setState(() {
      _at = DateTime(date.year, date.month, date.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    final cents = parseCents(_amount.text);
    if (cents == null) {
      setState(() {
        _error = 'Enter an amount from \$0.01 to ${moneyCents(maxRecordCents)}';
      });
      return;
    }
    final navigator = Navigator.of(context);
    await context.read<SavingsViewModel>().editEntry(
      widget.entry.id,
      cents: cents,
      at: _at,
    );
    navigator.pop();
  }

  Future<void> _delete() async {
    final model = context.read<SavingsViewModel>();
    final navigator = Navigator.of(context);
    final ok = await confirmDeleteEntry(context, widget.entry);
    if (ok != true) return;
    final removed = await model.deleteEntry(widget.entry.id);
    navigator.pop();
    if (removed == null) return;
    widget.messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted ${moneyCents(removed.cents)}'),
        action: SnackBarAction(
          key: const Key('undo-delete'),
          label: 'UNDO',
          onPressed: () => unawaited(model.restoreEntry(removed)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final when =
        '${l10n.formatMediumDate(_at)} · '
        '${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(_at))}';
    return AlertDialog(
      title: const Text('Edit saving'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AmountField(controller: _amount, error: _error, onSubmit: _save),
          const SizedBox(height: 12),
          TextButton.icon(
            key: const Key('edit-when'),
            onPressed: _pickWhen,
            icon: const Icon(Icons.schedule),
            label: Text(when),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('edit-delete'),
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          onPressed: _delete,
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('edit-save'),
          style: FilledButton.styleFrom(
            backgroundColor: Palette.gold,
            foregroundColor: Palette.outline,
          ),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.error,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('edit-amount'),
      controller: controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}(\.\d{0,2})?')),
      ],
      onSubmitted: (_) => onSubmit(),
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      decoration: InputDecoration(
        prefixText: '\$ ',
        labelText: 'Amount',
        errorText: error,
      ),
    );
  }
}

/// Destructive confirm for deleting one record.
Future<bool?> confirmDeleteEntry(BuildContext context, SaveEntry entry) =>
    showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${moneyCents(entry.cents)}?'),
        content: const Text(
          'This removes the saving from this goal. Your total, level and '
          'badges are recalculated. You can undo right after.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-record'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
