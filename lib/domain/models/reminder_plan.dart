/// Pure reminder rules: frequency, schedule and copy. No plugins here, so it
/// is fully unit-testable.
enum ReminderFrequency {
  daily(1, 'Daily'),
  everyOtherDay(2, 'Every other day'),
  everyThreeDays(3, 'Every three days'),
  weekly(7, 'Weekly'),
  never(0, 'Never');

  const ReminderFrequency(this.intervalDays, this.label);

  /// Days between reminders; 0 means no reminders.
  final int intervalDays;
  final String label;

  bool get enabled => intervalDays > 0;

  static ReminderFrequency? tryParse(String? name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

/// Reminder time of day (local). 7 pm: after work, when cravings and
/// impulse spending peak, and early enough to still act on it.
const reminderHour = 19;

/// How many future reminders are queued per (re)schedule. The queue is
/// rebuilt on every app launch and every change. 14 keeps daily users
/// covered for two weeks and stays far below the iOS limit of 64.
const reminderBatch = 14;

/// Calendar dates (local wall clock, [reminderHour]:00) of the next
/// [count] reminders after [now]. Steps are calendar days, so DST changes
/// do not shift the time of day.
List<DateTime> reminderTimes(
  DateTime now,
  ReminderFrequency f, {
  int count = reminderBatch,
}) {
  if (!f.enabled) return const [];
  var first = DateTime(now.year, now.month, now.day, reminderHour);
  if (!first.isAfter(now)) {
    first = DateTime(now.year, now.month, now.day + 1, reminderHour);
  }
  return [
    for (var i = 0; i < count; i++)
      DateTime(
        first.year,
        first.month,
        first.day + i * f.intervalDays,
        reminderHour,
      ),
  ];
}

typedef ReminderCopy = ({String title, String body});

/// On-brand rotating copy. [i] is the reminder's index in the batch.
ReminderCopy reminderCopy(int i, {required int dollars}) {
  final lines = <ReminderCopy>[
    dollars > 0
        ? (
            title: '💰 \$$dollars saved so far',
            body: 'Skip one more craving today and watch it grow.',
          )
        : (
            title: '💰 Your first dollar is waiting',
            body: 'Skip one craving today and bank what you saved.',
          ),
    (
      title: '🐷 Bank today\'s savings',
      body: 'Skipped something today? Add those dollars in QuitCash.',
    ),
    (
      title: '✨ What did you not spend today?',
      body: 'Bank it in QuitCash. Every dollar counts.',
    ),
    (
      title: '💪 Craving? Turn it into gold',
      body: 'Every skip is money kept. Tap to bank it.',
    ),
    (
      title: '🏆 Your next milestone is closer than you think',
      body: 'Open QuitCash and see how close you are.',
    ),
  ];
  return lines[i % lines.length];
}
