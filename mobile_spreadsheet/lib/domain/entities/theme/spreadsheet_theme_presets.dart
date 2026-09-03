import 'package:flutter/material.dart';
import 'spreadsheet_theme_config.dart';

/// Item representing a preset theme for gallery selection
class ThemePresetItem {
  final String id;
  final String name;
  final SpreadsheetThemeConfig config;

  const ThemePresetItem({
    required this.id,
    required this.name,
    required this.config,
  });
}

/// Collection of curated Full-Sheet and Header-Only preset themes
class SpreadsheetThemePresets {
  /// 10+ Full Sheet Presets
  static const List<ThemePresetItem> fullSheetPresets = [
    ThemePresetItem(
      id: 'default',
      name: 'Classic Excel',
      config: SpreadsheetThemeConfig(
        presetId: 'default',
        headerBgColor: Color(0xFFF5F5F5),
        headerTextColor: Color(0xFF212121),
        rowHeaderBgColor: Color(0xFFF5F5F5),
        rowHeaderTextColor: Color(0xFF212121),
        gridBgColor: Color(0xFFFFFFFF),
        borderColor: Color(0xFFE0E0E0),
        selectionColor: Color(0xFFE3F2FD),
        accentColor: Color(0xFF107C41), // Excel Green
      ),
    ),
    ThemePresetItem(
      id: 'dark_slate',
      name: 'Dark Slate',
      config: SpreadsheetThemeConfig(
        presetId: 'dark_slate',
        headerBgColor: Color(0xFF1E293B),
        headerTextColor: Color(0xFFF8FAFC),
        rowHeaderBgColor: Color(0xFF1E293B),
        rowHeaderTextColor: Color(0xFF94A3B8),
        gridBgColor: Color(0xFF0F172A),
        borderColor: Color(0xFF334155),
        selectionColor: Color(0xFF1E3A8A),
        accentColor: Color(0xFF38BDF8),
      ),
    ),
    ThemePresetItem(
      id: 'emerald',
      name: 'Emerald Forest',
      config: SpreadsheetThemeConfig(
        presetId: 'emerald',
        headerBgColor: Color(0xFF065F46),
        headerTextColor: Color(0xFFECFDF5),
        rowHeaderBgColor: Color(0xFF047857),
        rowHeaderTextColor: Color(0xFFA7F3D0),
        gridBgColor: Color(0xFFF0FDF4),
        borderColor: Color(0xFFA7F3D0),
        selectionColor: Color(0xFFD1FAE5),
        accentColor: Color(0xFF059669),
      ),
    ),
    ThemePresetItem(
      id: 'ocean_blue',
      name: 'Ocean Blue',
      config: SpreadsheetThemeConfig(
        presetId: 'ocean_blue',
        headerBgColor: Color(0xFF1E40AF),
        headerTextColor: Color(0xFFEFF6FF),
        rowHeaderBgColor: Color(0xFF1D4ED8),
        rowHeaderTextColor: Color(0xFFBFDBFE),
        gridBgColor: Color(0xFFF0F9FF),
        borderColor: Color(0xFFBAE6FD),
        selectionColor: Color(0xFFDBEAFE),
        accentColor: Color(0xFF2563EB),
      ),
    ),
    ThemePresetItem(
      id: 'sunset_crimson',
      name: 'Sunset Crimson',
      config: SpreadsheetThemeConfig(
        presetId: 'sunset_crimson',
        headerBgColor: Color(0xFF991B1B),
        headerTextColor: Color(0xFFFEF2F2),
        rowHeaderBgColor: Color(0xFFB91C1C),
        rowHeaderTextColor: Color(0xFFFCA5A5),
        gridBgColor: Color(0xFFFFF1F2),
        borderColor: Color(0xFFFECDD3),
        selectionColor: Color(0xFFFFE4E6),
        accentColor: Color(0xFFDC2626),
      ),
    ),
    ThemePresetItem(
      id: 'royal_purple',
      name: 'Royal Purple',
      config: SpreadsheetThemeConfig(
        presetId: 'royal_purple',
        headerBgColor: Color(0xFF5B21B6),
        headerTextColor: Color(0xFFF5F3FF),
        rowHeaderBgColor: Color(0xFF6D28D9),
        rowHeaderTextColor: Color(0xFFDDD6FE),
        gridBgColor: Color(0xFFFAF5FF),
        borderColor: Color(0xFFE9D5FF),
        selectionColor: Color(0xFFEDE9FE),
        accentColor: Color(0xFF7C3AED),
      ),
    ),
    ThemePresetItem(
      id: 'pastel_mint',
      name: 'Pastel Mint',
      config: SpreadsheetThemeConfig(
        presetId: 'pastel_mint',
        headerBgColor: Color(0xFFCCFBF1),
        headerTextColor: Color(0xFF115E59),
        rowHeaderBgColor: Color(0xFFE6FFFA),
        rowHeaderTextColor: Color(0xFF0F766E),
        gridBgColor: Color(0xFFF0FDFA),
        borderColor: Color(0xFF99F6E4),
        selectionColor: Color(0xFF99F6E4),
        accentColor: Color(0xFF0D9488),
      ),
    ),
    ThemePresetItem(
      id: 'rose_gold',
      name: 'Rose Gold',
      config: SpreadsheetThemeConfig(
        presetId: 'rose_gold',
        headerBgColor: Color(0xFF881337),
        headerTextColor: Color(0xFFFFF1F2),
        rowHeaderBgColor: Color(0xFF9F1239),
        rowHeaderTextColor: Color(0xFFFECDD3),
        gridBgColor: Color(0xFFFFF1F2),
        borderColor: Color(0xFFFDA4AF),
        selectionColor: Color(0xFFFECDD3),
        accentColor: Color(0xFFE11D48),
      ),
    ),
    ThemePresetItem(
      id: 'cyberpunk',
      name: 'Cyberpunk Neon',
      config: SpreadsheetThemeConfig(
        presetId: 'cyberpunk',
        headerBgColor: Color(0xFF18181B),
        headerTextColor: Color(0xFF38BDF8),
        rowHeaderBgColor: Color(0xFF27272A),
        rowHeaderTextColor: Color(0xFFF43F5E),
        gridBgColor: Color(0xFF09090B),
        borderColor: Color(0xFF3F3F46),
        selectionColor: Color(0xFF312E81),
        accentColor: Color(0xFFA855F7),
      ),
    ),
    ThemePresetItem(
      id: 'coffee_mocha',
      name: 'Mocha Coffee',
      config: SpreadsheetThemeConfig(
        presetId: 'coffee_mocha',
        headerBgColor: Color(0xFF78350F),
        headerTextColor: Color(0xFFFFFBEB),
        rowHeaderBgColor: Color(0xFF92400E),
        rowHeaderTextColor: Color(0xFFFDE68A),
        gridBgColor: Color(0xFFFFFBEB),
        borderColor: Color(0xFFFCD34D),
        selectionColor: Color(0xFFFEF3C7),
        accentColor: Color(0xFFD97706),
      ),
    ),
  ];

  /// 8+ Header-Only Presets
  static const List<ThemePresetItem> headerOnlyPresets = [
    ThemePresetItem(
      id: 'h_emerald',
      name: 'Emerald Header',
      config: SpreadsheetThemeConfig(
        presetId: 'h_emerald',
        headerBgColor: Color(0xFF047857),
        headerTextColor: Color(0xFFFFFFFF),
        borderColor: Color(0xFF059669),
        isHeaderOnly: true,
      ),
    ),
    ThemePresetItem(
      id: 'h_navy',
      name: 'Navy Header',
      config: SpreadsheetThemeConfig(
        presetId: 'h_navy',
        headerBgColor: Color(0xFF1E3A8A),
        headerTextColor: Color(0xFFFFFFFF),
        borderColor: Color(0xFF2563EB),
        isHeaderOnly: true,
      ),
    ),
    ThemePresetItem(
      id: 'h_crimson',
      name: 'Crimson Header',
      config: SpreadsheetThemeConfig(
        presetId: 'h_crimson',
        headerBgColor: Color(0xFF991B1B),
        headerTextColor: Color(0xFFFFFFFF),
        borderColor: Color(0xFFDC2626),
        isHeaderOnly: true,
      ),
    ),
    ThemePresetItem(
      id: 'h_purple',
      name: 'Purple Header',
      config: SpreadsheetThemeConfig(
        presetId: 'h_purple',
        headerBgColor: Color(0xFF6D28D9),
        headerTextColor: Color(0xFFFFFFFF),
        borderColor: Color(0xFF7C3AED),
        isHeaderOnly: true,
      ),
    ),
    ThemePresetItem(
      id: 'h_amber',
      name: 'Amber Header',
      config: SpreadsheetThemeConfig(
        presetId: 'h_amber',
        headerBgColor: Color(0xFFD97706),
        headerTextColor: Color(0xFFFFFFFF),
        borderColor: Color(0xFFF59E0B),
        isHeaderOnly: true,
      ),
    ),
    ThemePresetItem(
      id: 'h_teal',
      name: 'Teal Header',
      config: SpreadsheetThemeConfig(
        presetId: 'h_teal',
        headerBgColor: Color(0xFF0D9488),
        headerTextColor: Color(0xFFFFFFFF),
        borderColor: Color(0xFF14B8A6),
        isHeaderOnly: true,
      ),
    ),
    ThemePresetItem(
      id: 'h_dark',
      name: 'Midnight Header',
      config: SpreadsheetThemeConfig(
        presetId: 'h_dark',
        headerBgColor: Color(0xFF18181B),
        headerTextColor: Color(0xFF38BDF8),
        borderColor: Color(0xFF3F3F46),
        isHeaderOnly: true,
      ),
    ),
    ThemePresetItem(
      id: 'h_rose',
      name: 'Rose Header',
      config: SpreadsheetThemeConfig(
        presetId: 'h_rose',
        headerBgColor: Color(0xFFE11D48),
        headerTextColor: Color(0xFFFFFFFF),
        borderColor: Color(0xFFF43F5E),
        isHeaderOnly: true,
      ),
    ),
  ];
}
