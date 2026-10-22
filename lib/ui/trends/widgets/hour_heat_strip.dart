import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';

/// 24 cells, midnight to midnight; brighter gold = more skips that hour.
class HourHeatStrip extends StatelessWidget {
  const HourHeatStrip({super.key, required this.counts});
  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final maxC = counts.isEmpty ? 0 : counts.reduce(math.max);
    return Column(
      children: [
        Row(
          children: [
            for (var h = 0; h < counts.length; h++)
              Expanded(
                child: Container(
                  key: Key('heat-$h'),
                  height: 26,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Color.lerp(
                      const Color(0xFF2A2550),
                      Palette.gold,
                      maxC == 0 ? 0 : counts[h] / maxC,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final l in ['12a', '6a', '12p', '6p', '12a'])
              Text(
                l,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
          ],
        ),
      ],
    );
  }
}
