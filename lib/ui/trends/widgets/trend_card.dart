import 'package:flutter/material.dart';

/// Calm dark card used throughout Trends.
class TrendCard extends StatelessWidget {
  const TrendCard({super.key, required this.child, this.title});
  final Widget child;
  final String? title;

  static const surface = Color(0xFF16122F);

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
