import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/widgets/coin_painter.dart';

/// Golden for the four change coins (1¢, 5¢, 10¢, 25¢). No text drawn.
/// Update with: flutter test --update-goldens test/goldens
void main() {
  testWidgets('change coins', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(480, 120);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Palette.skyTop,
          child: Row(
            children: [
              for (final d in changeDenominations)
                SizedBox.square(
                  dimension: 120,
                  child: CustomPaint(
                    painter: painterFor(d, angle: 0.5, glint: 0.35),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await expectLater(find.byType(Row), matchesGoldenFile('change_coins.png'));
  });
}
