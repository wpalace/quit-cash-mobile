import 'package:flutter/material.dart';

/// Small labelled figure (Average per day, Best day, ...).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.detail,
  });
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (detail != null)
          Text(
            detail,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
      ],
    );
  }
}
