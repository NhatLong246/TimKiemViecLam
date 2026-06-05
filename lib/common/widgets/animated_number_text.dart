import 'package:flutter/material.dart';

class AnimatedNumberText extends StatelessWidget {
  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final Duration duration;

  const AnimatedNumberText(
    this.value, {
    super.key,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutQuart,
      builder: (context, val, child) {
        return Text(
          format(val),
          style: style,
        );
      },
    );
  }
}
