import 'package:flutter/material.dart';
import 'package:quit_cash_mobile/domain/models/trend_insights.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/trends/widgets/trend_card.dart';

/// One plain-language takeaway: emoji, a short headline, one line of why.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight});
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    return TrendCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(insight.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    color: Palette.goldLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.body,
                  style: const TextStyle(color: Colors.white70, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
