import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';

Future<(SavingsViewModel, InMemorySavingsRepository)> twoGoals() async {
  final repo = InMemorySavingsRepository.withGoal('Smoking')
    ..reminder = 'daily';
  final m = SavingsViewModel(repository: repo);
  await Future<void>.delayed(Duration.zero);
  await m.addSavings(20); // Smoking: \$20
  await m.addGoal('Fancy coffee', label: '  Latte habit ');
  await m.addSavings(5); // Coffee: \$5
  return (m, repo);
}

void main() {
  test('add goal: new goal is active with its own empty history', () async {
    final repo = InMemorySavingsRepository.withGoal('Smoking');
    final m = SavingsViewModel(repository: repo);
    await Future<void>.delayed(Duration.zero);
    await m.addSavings(20);
    final g = await m.addGoal('Vaping');
    expect(m.goals.map((g) => g.habit), ['Smoking', 'Vaping']);
    expect(m.activeGoal, g);
    expect(m.progress.total, 0);
    expect(m.progress.unlocked, isEmpty);
    expect(repo.goals, hasLength(2));
    expect(repo.active, g.id);
  });

  test('labels are trimmed, blank labels fall back to the habit', () async {
    final (m, _) = await twoGoals();
    expect(m.activeGoal?.title, 'Latte habit');
    expect(m.activeGoal?.emoji, '☕');
    final g = await m.addGoal('Takeout', label: '   ');
    expect(g.label, isNull);
    expect(g.title, 'Takeout');
  });

  test('switch: each goal keeps its own total, level and badges', () async {
    final (m, repo) = await twoGoals();
    expect(m.progress.total, 5);
    expect(m.progress.level, 1);
    await m.switchGoal('g1');
    expect(m.habit, 'Smoking');
    expect(m.progress.total, 20);
    expect(m.progress.level, 2);
    expect(m.progress.unlocked, containsAll(['first', 'ten']));
    expect(repo.active, 'g1');
    expect(m.totalCentsAllGoals, 2500);
    // Persisted: a new model opens on the same goal.
    final again = SavingsViewModel(repository: repo);
    await Future<void>.delayed(Duration.zero);
    expect(again.habit, 'Smoking');
    expect(again.progress.total, 20);
  });

  test('delete active goal switches to another one', () async {
    final (m, repo) = await twoGoals();
    final coffee = m.activeGoal?.id;
    await m.deleteGoal(coffee ?? '');
    expect(m.goals.map((g) => g.id), ['g1']);
    expect(m.activeGoal?.id, 'g1');
    expect(m.progress.total, 20);
    expect(repo.entries.containsKey(coffee), isFalse);
    expect(repo.active, 'g1');
  });

  test('delete an inactive goal keeps the active one', () async {
    final (m, _) = await twoGoals();
    final active = m.activeGoal;
    await m.deleteGoal('g1');
    expect(m.activeGoal, active);
    expect(m.goals, [active]);
  });

  test(
    'deleting the last goal returns to onboarding, keeps settings',
    () async {
      final (m, repo) = await twoGoals();
      await m.setShowHundred(true);
      for (final g in [...m.goals]) {
        await m.deleteGoal(g.id);
      }
      expect(m.goals, isEmpty);
      expect(m.habit, isNull); // the app shows onboarding
      expect(m.progress.total, 0);
      expect(repo.active, isNull);
      expect(repo.entries, isEmpty);
      expect(m.reminder?.name, 'daily');
      expect(m.showHundred, isTrue);
    },
  );

  test('reset clears only the current goal', () async {
    final (m, repo) = await twoGoals();
    await m.reset();
    expect(m.progress.total, 0);
    expect(m.goals, hasLength(2));
    await m.switchGoal('g1');
    expect(m.progress.total, 20);
    expect(repo.entries['g1'], hasLength(1));
  });
}
