import 'dart:math';
import 'package:intl/intl.dart';

/// All supported number formats (matching Excel's built-in list)
enum CellFormat {
  general,
  number,
  currency,
  accounting,
  shortDate,
  longDate,
  time,
  percentage,
  fraction,
  scientific,
  text,
  custom,
}

extension CellFormatExtension on CellFormat {
  String get label {
    switch (this) {
      case CellFormat.general:     return 'General';
      case CellFormat.number:      return 'Number';
      case CellFormat.currency:    return 'Currency';
      case CellFormat.accounting:  return 'Accounting';
      case CellFormat.shortDate:   return 'Short Date';
      case CellFormat.longDate:    return 'Long Date';
      case CellFormat.time:        return 'Time';
      case CellFormat.percentage:  return 'Percentage';
      case CellFormat.fraction:    return 'Fraction';
      case CellFormat.scientific:  return 'Scientific';
      case CellFormat.text:        return 'Text';
      case CellFormat.custom:      return 'Custom';
    }
  }

  String get storageKey {
    return name; // uses enum name for serialization
  }

  static CellFormat fromKey(String key) {
    return CellFormat.values.firstWhere(
      (e) => e.name == key,
      orElse: () => CellFormat.general,
    );
  }
}

/// Format a raw cell string value into its display representation
String formatCellValue(String raw, CellFormat fmt) {
  if (raw.isEmpty) return raw;

  switch (fmt) {
    case CellFormat.general:
      return raw;

    case CellFormat.text:
      return raw;

    case CellFormat.number:
      final num? n = num.tryParse(raw);
      if (n == null) return raw;
      return NumberFormat('#,##0.00').format(n);

    case CellFormat.currency:
      final num? n = num.tryParse(raw);
      if (n == null) return raw;
      return '₹${NumberFormat('#,##0.00').format(n)}';

    case CellFormat.accounting:
      final num? n = num.tryParse(raw);
      if (n == null) return raw;
      // Accounting style: symbol left-aligned, value right-aligned (simplified)
      return '₹ ${NumberFormat('#,##0.00').format(n)}';

    case CellFormat.percentage:
      final num? n = num.tryParse(raw);
      if (n == null) return raw;
      return '${NumberFormat('#,##0.##').format(n * 100)}%';

    case CellFormat.scientific:
      final double? n = double.tryParse(raw);
      if (n == null) return raw;
      return _toScientific(n);

    case CellFormat.fraction:
      final double? n = double.tryParse(raw);
      if (n == null) return raw;
      return _toFraction(n);

    case CellFormat.shortDate:
      final DateTime? dt = _parseDate(raw);
      if (dt == null) return raw;
      return DateFormat('dd-MM-yyyy').format(dt);

    case CellFormat.longDate:
      final DateTime? dt = _parseDate(raw);
      if (dt == null) return raw;
      return DateFormat('EEEE, MMMM d, yyyy').format(dt);

    case CellFormat.time:
      final DateTime? dt = _parseDate(raw);
      if (dt == null) return raw;
      return DateFormat('hh:mm:ss a').format(dt);

    case CellFormat.custom:
      // For now, fall through to general
      return raw;
  }
}

/// Parse date: try Excel serial number (days since 1900-01-01), ISO string, or slash/dash formats
DateTime? _parseDate(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  // Try Excel serial (number of days since 1899-12-30)
  final double? serial = double.tryParse(trimmed);
  if (serial != null && serial > 0 && serial < 2958465) {
    final base = DateTime(1899, 12, 30);
    return base.add(Duration(
      days: serial.truncate(),
      microseconds: ((serial % 1) * Duration.microsecondsPerDay).round(),
    ));
  }

  // Try ISO parse (e.g. "2026-07-08")
  try {
    return DateTime.parse(trimmed);
  } catch (_) {}

  // Try parsing common date string patterns: DD/MM/YYYY, YYYY/MM/DD, DD-MM-YYYY
  final parts = trimmed.split(RegExp(r'[/.-]'));
  if (parts.length == 3) {
    final int? p1 = int.tryParse(parts[0]);
    final int? p2 = int.tryParse(parts[1]);
    final int? p3 = int.tryParse(parts[2]);
    if (p1 != null && p2 != null && p3 != null) {
      if (p1 > 1000) {
        // YYYY / MM / DD
        return DateTime(p1, p2.clamp(1, 12), p3.clamp(1, 31));
      } else if (p3 > 1000) {
        // DD / MM / YYYY or MM / DD / YYYY
        final month = (p2 <= 12) ? p2 : p1;
        final day = (p2 <= 12) ? p1 : p2;
        return DateTime(p3, month.clamp(1, 12), day.clamp(1, 31));
      }
    }
  }
  return null;
}

/// Convert double to engineering-style fraction (e.g., 0.75 → 3/4)
String _toFraction(double value) {
  if (value == value.truncateToDouble()) {
    return value.truncate().toString();
  }
  final int intPart = value.truncate();
  final double fracPart = (value - intPart).abs();

  // Find best denominator up to 99
  int bestNum = 1, bestDen = 1;
  double bestErr = double.infinity;
  for (int den = 1; den <= 99; den++) {
    final int num = (fracPart * den).round();
    final double err = (fracPart - num / den).abs();
    if (err < bestErr) {
      bestErr = err;
      bestNum = num;
      bestDen = den;
    }
  }

  if (bestDen == 1) return (intPart + bestNum).toString();
  if (intPart == 0) return '$bestNum/$bestDen';
  return '$intPart $bestNum/$bestDen';
}

/// Convert double to scientific notation (e.g., 123456789 → 1.23457E+08)
String _toScientific(double value) {
  if (value == 0) return '0.00000E+00';
  final int exp = (log(value.abs()) / ln10).floor();
  final double mantissa = value / pow(10, exp);
  final String expStr = exp >= 0 ? '+${exp.toString().padLeft(2, '0')}' : '-${exp.abs().toString().padLeft(2, '0')}';
  return '${NumberFormat('0.00000').format(mantissa)}E$expStr';
}
