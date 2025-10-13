import 'package:flutter/material.dart';

class KadiColors {
  static const Color black = Color(0xFF0B0B0B);
  static const Color white = Color(0xFFFFFFFF);
  static const Color red = Color(0xFFD62828);
  static const Color green = Color(0xFF005F43);
  static const Color gold = Color(0xFFFFC300);
  static const Color grey = Color(0xFFBDBDBD);

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF001B18), Color(0xFF013220)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}