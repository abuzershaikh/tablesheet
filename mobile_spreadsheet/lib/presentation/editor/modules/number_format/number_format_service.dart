import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'number_format_model.dart';

/// Persists per-cell number formats to SharedPreferences.
/// Key structure: fmt_<sheetId> → JSON map of "row:col" → formatName
class NumberFormatService {
  NumberFormatService._();
  static final NumberFormatService instance = NumberFormatService._();

  static String _prefsKey(String sheetId) => 'fmt_$sheetId';

  /// Load all formats for a sheet. Returns empty map if none saved.
  Future<Map<String, CellFormat>> loadFormats(String sheetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey(sheetId));
      if (raw == null || raw.isEmpty) return {};
      final Map<String, dynamic> decoded = jsonDecode(raw);
      return decoded.map(
        (key, val) => MapEntry(key, CellFormatExtension.fromKey(val as String)),
      );
    } catch (_) {
      return {};
    }
  }

  /// Save a single cell's format.
  Future<void> saveFormat(String sheetId, int row, int col, CellFormat fmt) async {
    final formats = await loadFormats(sheetId);
    final key = '$row:$col';
    if (fmt == CellFormat.general) {
      formats.remove(key); // general is the default, no need to store
    } else {
      formats[key] = fmt;
    }
    await _persistFormats(sheetId, formats);
  }

  /// Save multiple cells' formats at once (for multi-select apply).
  Future<void> saveFormats(
    String sheetId,
    List<String> cellKeys,
    CellFormat fmt,
  ) async {
    final formats = await loadFormats(sheetId);
    for (final key in cellKeys) {
      if (fmt == CellFormat.general) {
        formats.remove(key);
      } else {
        formats[key] = fmt;
      }
    }
    await _persistFormats(sheetId, formats);
  }

  /// Get format for a single cell.
  Future<CellFormat> getFormat(String sheetId, int row, int col) async {
    final formats = await loadFormats(sheetId);
    return formats['$row:$col'] ?? CellFormat.general;
  }

  /// Clear all formats for a sheet.
  Future<void> clearFormats(String sheetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(sheetId));
  }

  Future<void> _persistFormats(
    String sheetId,
    Map<String, CellFormat> formats,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      formats.map((k, v) => MapEntry(k, v.storageKey)),
    );
    await prefs.setString(_prefsKey(sheetId), encoded);
  }
}
