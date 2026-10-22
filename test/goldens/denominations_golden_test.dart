import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/widgets/coin_painter.dart';

/// Golden for the key art: every denomination at a fixed angle and glint.
/// The painters draw no text, so no font pinning is needed.
/// Update with: flutter test --update-goldens test/goldens
void main() {
  testWidgets('denominations', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(120.0 * denominations.length, 120);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Palette.skyTop,
          child: Row(
            children: [
              for (final d in denominations)
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
    await expectLater(find.byType(Row), matchesGoldenFile('denominations.png'));
  });
}
