import 'package:flutter/material.dart';

class Animations {
  /// Fades in a widget with slight scaling
  static Widget fadeIn({required Widget child, int duration = 500}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: duration),
      builder: (context, value, _) => Opacity(
        opacity: value,
        child: Transform.scale(scale: 0.95 + (value * 0.05), child: child),
      ),
    );
  }

  /// Simulates slow-motion effect for card plays
  static Widget slowMotionCard({
    required Widget child,
    int duration = 700,
    Offset from = const Offset(0, 20),
  }) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: from, end: Offset.zero),
      duration: Duration(milliseconds: duration),
      curve: Curves.easeOutCubic,
      builder: (context, offset, _) => Transform.translate(
        offset: offset,
        child: child,
      ),
    );
  }

  /// Bounce animation for highlighting turns or winners
  static Widget bounce({
    required Widget child,
    int duration = 1000,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: duration),
      curve: Curves.elasticOut,
      builder: (context, value, _) => Transform.scale(
        scale: 1.0 + (0.05 * value),
        child: child,
      ),
    );
  }
}