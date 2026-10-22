import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/data/repositories/prefs_savings_repository.dart';
import 'package:quit_cash_mobile/data/services/reminder_service.dart';
import 'package:quit_cash_mobile/domain/models/reminder_plan.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class FakeReminders implements ReminderService {
  FakeReminders({this.grant = true});
  final bool grant;

  @override
  bool get supported => true;
  int permissionRequests = 0;
  final scheduled = <ReminderFrequency>[];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<void> schedule(
    ReminderFrequency frequency, {
    required int streak,
    required int coins,
  }) async => scheduled.add(frequency);
}

void main() {
  group('reminderTimes', () {
    final morning = DateTime(2026, 10, 19, 9);
    final evening = DateTime(2026, 10, 19, 20);

    test('intervals per frequency', () {
      expect(ReminderFrequency.daily.intervalDays, 1);
      expect(ReminderFrequency.everyOtherDay.intervalDays, 2);
      expect(ReminderFrequency.everyThreeDays.intervalDays, 3);
      expect(ReminderFrequency.weekly.intervalDays, 7);
      expect(ReminderFrequency.never.enabled, isFalse);
    });

    for (final f in ReminderFrequency.values.where((f) => f.enabled)) {
      test('${f.name}: ${f.intervalDays}-day steps at 7 pm', () {
        final t = reminderTimes(morning, f);
        expect(t, hasLength(reminderBatch));
        expect(t.first, DateTime(2026, 10, 19, reminderHour));
        for (var i = 1; i < t.length; i++) {
          final a = t[i - 1], b = t[i];
          expect(b.hour, reminderHour);
          expect(
            DateTime.utc(
              b.year,
              b.month,
              b.day,
            ).difference(DateTime.utc(a.year, a.month, a.day)).inDays,
            f.intervalDays,
          );
        }
      });
    }

    test('after 7 pm the first reminder is tomorrow', () {
      expect(
        reminderTimes(evening, ReminderFrequency.daily).first,
        DateTime(2026, 10, 20, reminderHour),
      );
      expect(
        reminderTimes(
          DateTime(2026, 10, 19, 19),
          ReminderFrequency.daily,
        ).first,
        DateTime(2026, 10, 20, reminderHour),
      );
    });

    test('rolls over months and years', () {
      final t = reminderTimes(
        DateTime(2026, 12, 30, 21),
        ReminderFrequency.weekly,
        count: 2,
      );
      expect(t, [DateTime(2026, 12, 31, 19), DateTime(2027, 1, 7, 19)]);
    });

    test('never schedules nothing', () {
      expect(reminderTimes(morning, ReminderFrequency.never), isEmpty);
    });
  });

  test('copy rotates and mentions streak and coins', () {
    final all = [
      for (var i = 0; i < 5; i++) reminderCopy(i, streak: 4, coins: 37),
    ];
    expect(all.map((c) => c.title).toSet(), hasLength(5));
    expect(all.any((c) => c.title.contains('4-day streak')), isTrue);
    expect(all.any((c) => c.body.contains('37 coins')), isTrue);
    expect(reminderCopy(5, streak: 4, coins: 37), all[0]);
    expect(reminderCopy(1, streak: 0, coins: 0).title, contains('new streak'));
  });

  test('tryParse round-trips names and rejects junk', () {
    for (final f in ReminderFrequency.values) {
      expect(ReminderFrequency.tryParse(f.name), f);
    }
    expect(ReminderFrequency.tryParse(null), isNull);
    expect(ReminderFrequency.tryParse('hourly'), isNull);
  });

  test('prefs repository persists the reminder choice', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    expect((await PrefsSavingsRepository().loadReminder()).valueOrNull, isNull);
    await PrefsSavingsRepository().saveReminder('weekly');
    expect((await PrefsSavingsRepository().loadReminder()).valueOrNull, 'weekly');
  });

  group('model', () {
    Future<(SavingsViewModel, FakeReminders, InMemorySavingsRepository)> make({
      String? stored,
      bool grant = true,
    }) async {
      final repo = InMemorySavingsRepository()..reminder = stored;
      final fake = FakeReminders(grant: grant);
      final m = SavingsViewModel(repository: repo, reminders: fake);
      await Future<void>.delayed(Duration.zero);
      return (m, fake, repo);
    }

    test('loads stored choice and reschedules on launch', () async {
      final (m, fake, _) = await make(stored: 'everyThreeDays');
      expect(m.reminder, ReminderFrequency.everyThreeDays);
      expect(fake.scheduled, [ReminderFrequency.everyThreeDays]);
      expect(fake.permissionRequests, 0);
    });

    test('legacy user without a choice: null, nothing scheduled', () async {
      final (m, fake, _) = await make();
      expect(m.reminder, isNull);
      expect(fake.scheduled, isEmpty);
    });

    test('Never stores choice without asking for permission', () async {
      final (m, fake, repo) = await make();
      expect(await m.setReminder(ReminderFrequency.never), isTrue);
      expect(fake.permissionRequests, 0);
      expect(repo.reminder, 'never');
      expect(fake.scheduled.last, ReminderFrequency.never);
    });

    test('non-Never asks permission and reports denial', () async {
      final (m, fake, repo) = await make(grant: false);
      expect(await m.setReminder(ReminderFrequency.daily), isFalse);
      expect(fake.permissionRequests, 1);
      expect(repo.reminder, 'daily');
    });
  });

  test(
    'unsupported platform (web): no permission prompt, no warning',
    () async {
      final m = SavingsViewModel(repository: InMemorySavingsRepository());
      await Future<void>.delayed(Duration.zero);
      expect(await m.setReminder(ReminderFrequency.daily), isTrue);
      expect(m.reminder, ReminderFrequency.daily);
    },
  );

  test('noop service (web) never throws', () async {
    const s = NoopReminderService();
    expect(s.supported, isFalse);
    expect(await s.requestPermission(), isFalse);
    await s.schedule(ReminderFrequency.daily, streak: 1, coins: 1);
  });
}
