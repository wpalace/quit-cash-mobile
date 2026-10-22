import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/ui/core/widgets/coin_rain.dart';
import 'package:quit_cash_mobile/ui/core/widgets/spinning_coin.dart';

Future<void> showCelebration(BuildContext context, Celebration cel) {
  HapticFeedback.heavyImpact();
  final title = cel.newLevel != null ? 'LEVEL UP!' : 'BADGE UNLOCKED!';
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'celebration',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 450),
    transitionBuilder: (context, a, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
      child: child,
    ),
    pageBuilder: (context, _, _) => Stack(
      children: [
        const Positioned.fill(child: CoinRain()),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Palette.skyBottom, Palette.skyTop],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Palette.gold, width: 4),
              ),
              // Scrolls when many badges unlock at once (a big first save).
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SpinningCoin(size: 90, sparkles: true),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Palette.gold,
                        shadows: [
                          Shadow(color: Palette.outline, offset: Offset(2, 3)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (cel.newLevel != null)
                      Text(
                        'You reached level ${cel.newLevel}!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    for (final b in cel.badges)
                      ListTile(
                        leading: Text(
                          b.emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                        title: Text(
                          b.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          b.description,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.gold,
                        foregroundColor: Palette.outline,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'AWESOME',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
