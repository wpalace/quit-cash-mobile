/// Habits offered when creating a goal: (emoji, name).
const habits = [
  ('🚬', 'Smoking'),
  ('💨', 'Vaping'),
  ('☕', 'Fancy coffee'),
  ('🍔', 'Takeout'),
  ('🍺', 'Drinking'),
  ('🛍️', 'Impulse buys'),
  ('🎰', 'Gambling'),
  ('✨', 'Something else'),
];

/// Emoji for a habit name; unknown habits get a sparkle.
String emojiForHabit(String habit) =>
    habits.firstWhere((h) => h.$2 == habit, orElse: () => ('✨', habit)).$1;
