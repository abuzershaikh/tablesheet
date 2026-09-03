import 'package:flutter/material.dart';

enum PivotThemeMode {
  light,
  dark,
  professionalBlue,
  vibrantEmerald,
  monochrome
}

class PivotTheme {
  final PivotThemeMode mode;
  final Color headerBgColor;
  final Color headerTextColor;
  final Color rowBgColor;
  final Color alternateRowBgColor;
  final Color textColor;
  final Color borderColor;
  final double borderWidth;
  final Color accentColor;

  const PivotTheme({
    this.mode = PivotThemeMode.professionalBlue,
    required this.headerBgColor,
    required this.headerTextColor,
    required this.rowBgColor,
    required this.alternateRowBgColor,
    required this.textColor,
    required this.borderColor,
    this.borderWidth = 1.0,
    required this.accentColor,
  });

  factory PivotTheme.fromMode(PivotThemeMode mode) {
    switch (mode) {
      case PivotThemeMode.dark:
        return const PivotTheme(
          mode: PivotThemeMode.dark,
          headerBgColor: Color(0xFF1E293B),
          headerTextColor: Colors.white,
          rowBgColor: Color(0xFF0F172A),
          alternateRowBgColor: Color(0xFF1E293B),
          textColor: Color(0xFFF8FAFC),
          borderColor: Color(0xFF334155),
          accentColor: Color(0xFF38BDF8),
        );
      case PivotThemeMode.vibrantEmerald:
        return const PivotTheme(
          mode: PivotThemeMode.vibrantEmerald,
          headerBgColor: Color(0xFF065F46),
          headerTextColor: Colors.white,
          rowBgColor: Colors.white,
          alternateRowBgColor: Color(0xFFECFDF5),
          textColor: Color(0xFF064E3B),
          borderColor: Color(0xFFA7F3D0),
          accentColor: Color(0xFF10B981),
        );
      case PivotThemeMode.monochrome:
        return const PivotTheme(
          mode: PivotThemeMode.monochrome,
          headerBgColor: Color(0xFF18181B),
          headerTextColor: Colors.white,
          rowBgColor: Colors.white,
          alternateRowBgColor: Color(0xFFF4F4F5),
          textColor: Color(0xFF18181B),
          borderColor: Color(0xFFE4E4E7),
          accentColor: Color(0xFF27272A),
        );
      case PivotThemeMode.light:
        return const PivotTheme(
          mode: PivotThemeMode.light,
          headerBgColor: Color(0xFF2563EB),
          headerTextColor: Colors.white,
          rowBgColor: Colors.white,
          alternateRowBgColor: Color(0xFFF8FAFC),
          textColor: Color(0xFF1E293B),
          borderColor: Color(0xFFCBD5E1),
          accentColor: Color(0xFF1D4ED8),
        );
      case PivotThemeMode.professionalBlue:
      default:
        return const PivotTheme(
          mode: PivotThemeMode.professionalBlue,
          headerBgColor: Color(0xFF1E40AF),
          headerTextColor: Colors.white,
          rowBgColor: Colors.white,
          alternateRowBgColor: Color(0xFFEFF6FF),
          textColor: Color(0xFF1E3A8A),
          borderColor: Color(0xFFBFDBFE),
          accentColor: Color(0xFF3B82F6),
        );
    }
  }
}
