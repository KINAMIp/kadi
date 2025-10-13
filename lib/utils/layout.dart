import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Layout and geometry helpers for arranging cards & players.
class Layout {
  static const double cardWidth  = 72;
  static const double cardHeight = 100;
  static const double cardRadius = 10;

  /// Calculates evenly spaced circular positions for n players.
  /// Useful for arranging avatars or cards around the table.
  static List<Offset> ringPositions(Size size, int n, {double margin = 40}) {
    final List<Offset> positions = [];
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - margin;

    for (int i = 0; i < n; i++) {
      final angle = (2 * 3.1415926 / n) * i - 3.1415926 / 2;
      final dx = center.dx + radius * Math.cos(angle);
      final dy = center.dy + radius * Math.sin(angle);
      positions.add(Offset(dx, dy));
    }
    return positions;
  }
}

/// Helper alias so we can use `Math.cos` / `Math.sin`.
class Math {
  static double cos(double x) => Math._cos(x);
  static double sin(double x) => Math._sin(x);
  static double _cos(double x) => math.cos(x);
  static double _sin(double x) => math.sin(x);
}

