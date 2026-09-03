import 'package:flutter/material.dart';

/// Application color scheme
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF1976D2);  // Blue
  static const Color primaryDark = Color(0xFF004BA0);
  static const Color primaryLight = Color(0xFFE3F2FD);
  
  // Accent Colors
  static const Color accent = Color(0xFF4CAF50);  // Green
  static const Color accentDark = Color(0xFF388E3C);
  static const Color accentLight = Color(0xFFC8E6C9);
  
  // Background Colors
  static const Color surface = Color(0xFFFFFFFF);  // White
  static const Color background = Color(0xFFFAFAFA);  // Off-white
  static const Color header = Color(0xFFF5F5F5);  // Light Gray
  static const Color divider = Color(0xFFE0E0E0);  // Border Gray
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212121);  // Almost Black
  static const Color textSecondary = Color(0xFF757575);  // Medium Gray
  static const Color textHint = Color(0xFFBDBDBD);  // Light Gray
  static const Color textError = Color(0xFFC62828);  // Red
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);  // Green
  static const Color warning = Color(0xFFFFC107);  // Amber
  static const Color error = Color(0xFFF44336);  // Red
  static const Color info = Color(0xFF2196F3);  // Blue
  
  // Cell States
  static const Color cellSelected = Color(0xFFE3F2FD);  // Light Blue
  static const Color cellEditing = Color(0xFF4CAF50);  // Green
  static const Color cellError = Color(0xFFFFEBEE);  // Light Red
  static const Color cellBorder = Color(0xFFE0E0E0);  // Gray
  static const Color cellSelectedBorder = Color(0xFF1976D2);  // Blue
  
  // Grid Colors
  static const Color gridLine = Color(0xFFE0E0E0);
  static const Color gridBackground = Colors.white;
  
  // Overlay
  static const Color overlay = Color(0x80000000);  // Semi-transparent black
  static const Color shimmer = Color(0xFFE0E0E0);
  
  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF2196F3),  // Blue
    Color(0xFF4CAF50),  // Green
    Color(0xFFFFC107),  // Amber
    Color(0xFFF44336),  // Red
    Color(0xFF9C27B0),  // Purple
    Color(0xFFFF9800),  // Orange
    Color(0xFF00BCD4),  // Cyan
    Color(0xFF8BC34A),  // Light Green
  ];
}
