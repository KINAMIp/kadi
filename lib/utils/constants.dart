import 'package:flutter/material.dart';

/// App theming & timing constants used across the app.
class AppColors {
  static const tableGreen = Color(0xFF196A3B);
  static const cardBack   = Color(0xFF17335C);
  static const highlight  = Color(0xFFFFD54F);
  static const winGlow    = Color(0xFF4CAF50);
}

class KadiDurations {
  /// How long a player's turn lasts.
  static const Duration turnTimeout = Duration(seconds: 30);
}