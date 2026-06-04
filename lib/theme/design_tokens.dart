import 'package:flutter/material.dart';

abstract final class DesignTokens {
  static const slate950 = Color(0xFF020617);
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate200 = Color(0xFFE2E8F0);
  static const white = Color(0xFFFFFFFF);

  static const blue600 = Color(0xFF2563EB);
  static const violet500 = Color(0xFF8B5CF6);
  static const green500 = Color(0xFF22C55E);
  static const amber500 = Color(0xFFEAB308);

  static const cardBg = slate800;
  static const borderSubtle = slate700;

  static const radiusSm = BorderRadius.all(Radius.circular(8));
  static const radiusMd = BorderRadius.all(Radius.circular(12));
  static const radiusLg = BorderRadius.all(Radius.circular(16));

  static const composerShadow = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 16,
      offset: Offset(0, -4),
    ),
  ];
}
