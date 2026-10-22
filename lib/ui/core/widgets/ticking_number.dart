
import 'package:flutter/material.dart';


/// Number that rolls smoothly to its new value (slot-machine feel).
class TickingNumber extends StatelessWidget {
  const TickingNumber({
    super.key,
    required this.value,
    required this.format,
    required this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  final double value;
  final String Function(double) format;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}
