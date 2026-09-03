import 'dart:math' as math;
import '../super_engine/formula_utils.dart';

/// Production-grade AutoFill Engine for Spreadsheets
/// Handles numeric series, date series, time series, boolean cycling,
/// formula reference shifting, and text repetition.
class AutoFillEngine {
  /// Shifts formula references for AutoFill operations.
  static String shiftFormulaForAutoFill(
    String formula, {
    required int rowDelta,
    required int colDelta,
  }) {
    if (!formula.startsWith('=')) return formula;

    final refRegex = RegExp(r'(\$?)([A-Z]+)(\$?)([0-9]+)');

    return formula.replaceAllMapped(refRegex, (match) {
      final colAbs = match.group(1)!;
      final colStr = match.group(2)!;
      final rowAbs = match.group(3)!;
      final rowStr = match.group(4)!;

      int col = _colIndexFromStr(colStr);
      int row = (int.tryParse(rowStr) ?? 1) - 1;

      if (rowAbs.isEmpty && rowDelta != 0) {
        row = math.max(0, row + rowDelta);
      }
      if (colAbs.isEmpty && colDelta != 0) {
        col = math.max(0, col + colDelta);
      }

      final newColStr = _colStrFromIndex(col);
      final newRowStr = '${row + 1}';

      return '$colAbs$newColStr$rowAbs$newRowStr';
    });
  }

  /// Calculates the next value for a cell at [targetIndex]
  static String calculateNextValue({
    required List<String> sourceValues,
    required int targetIndex,
    int rowDelta = 0,
    int colDelta = 0,
  }) {
    if (sourceValues.isEmpty) return '';

    final n = sourceValues.length;
    if (targetIndex < n) {
      return sourceValues[targetIndex];
    }

    // 1. Formula Series
    final firstVal = sourceValues[0].trim();
    if (firstVal.startsWith('=')) {
      final sourceFormula = sourceValues[(targetIndex - n) % n];
      final currentCycle = (targetIndex ~/ n);
      return shiftFormulaForAutoFill(
        sourceFormula,
        rowDelta: rowDelta * currentCycle,
        colDelta: colDelta * currentCycle,
      );
    }

    // 2. Numeric Series
    final numbers = <double>[];
    bool allNumeric = true;
    for (final v in sourceValues) {
      final d = double.tryParse(v.trim().replaceAll(',', ''));
      if (d != null) {
        numbers.add(d);
      } else {
        allNumeric = false;
        break;
      }
    }

    if (allNumeric && numbers.isNotEmpty) {
      if (numbers.length == 1) {
        return sourceValues[0];
      } else {
        final first = numbers.first;
        final last = numbers.last;
        final step = (last - first) / (numbers.length - 1);
        final calculatedVal = first + (targetIndex * step);
        return FormulaUtils.formatNumber(calculatedVal);
      }
    }

    // 3. Date Series (YYYY-MM-DD)
    final dates = <DateTime>[];
    bool allDates = true;
    for (final v in sourceValues) {
      final parsed = DateTime.tryParse(v.trim());
      if (parsed != null) {
        dates.add(parsed);
      } else {
        allDates = false;
        break;
      }
    }

    if (allDates && dates.isNotEmpty) {
      if (dates.length == 1) {
        final nextDate = dates[0].add(Duration(days: targetIndex));
        return _formatDate(nextDate);
      } else {
        final daysStep = dates.last.difference(dates.first).inDays / (dates.length - 1);
        final nextDate = dates.first.add(Duration(days: (targetIndex * daysStep).round()));
        return _formatDate(nextDate);
      }
    }

    // 4. Time Series (HH:MM or HH:MM:SS)
    final times = <int>[]; // total minutes
    bool allTimes = true;
    for (final v in sourceValues) {
      final t = _parseTime(v.trim());
      if (t != null) {
        times.add(t);
      } else {
        allTimes = false;
        break;
      }
    }

    if (allTimes && times.isNotEmpty) {
      if (times.length == 1) {
        final nextMinutes = times[0] + targetIndex; // increment by 1 minute
        return _formatTime(nextMinutes);
      } else {
        final first = times.first;
        final last = times.last;
        final step = (last - first) / (times.length - 1);
        final nextMinutes = first + (targetIndex * step).round();
        return _formatTime(nextMinutes % (24 * 60)); // wrap around 24h
      }
    }

    // 5. Boolean/Checkbox cycling (TRUE/FALSE, Yes/No, 1/0, ✓/✗)
    final boolResult = _tryBooleanCycle(sourceValues, targetIndex);
    if (boolResult != null) return boolResult;

    // 6. Month name series (Jan, Feb, Mar... or January, February...)
    final monthResult = _tryMonthSeries(sourceValues, targetIndex);
    if (monthResult != null) return monthResult;

    // 7. Day name series (Mon, Tue... or Monday, Tuesday...)
    final dayResult = _tryDaySeries(sourceValues, targetIndex);
    if (dayResult != null) return dayResult;

    // 8. Text with trailing number (Item1, Item2 → Item3)
    final textNumResult = _tryTextNumberSeries(sourceValues, targetIndex);
    if (textNumResult != null) return textNumResult;

    // 9. Fallback: Cyclic repeat
    return sourceValues[targetIndex % n];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SERIES DETECTION HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Parse HH:MM or HH:MM:SS → total minutes
  static int? _parseTime(String s) {
    final parts = s.split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  /// Format total minutes → HH:MM
  static String _formatTime(int totalMinutes) {
    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Boolean/checkbox cycling
  static String? _tryBooleanCycle(List<String> src, int idx) {
    final pairs = [
      ['TRUE', 'FALSE'],
      ['true', 'false'],
      ['True', 'False'],
      ['Yes', 'No'],
      ['yes', 'no'],
      ['YES', 'NO'],
      ['✓', '✗'],
      ['✔', '✘'],
      ['1', '0'],
    ];

    for (final pair in pairs) {
      bool matches = true;
      for (int i = 0; i < src.length; i++) {
        if (src[i].trim() != pair[0] && src[i].trim() != pair[1]) {
          matches = false;
          break;
        }
      }
      if (matches && src.isNotEmpty) {
        // Continue the alternation pattern
        if (src.length == 1) {
          // Single value: alternate
          return idx % 2 == 0 ? src[0].trim() : (src[0].trim() == pair[0] ? pair[1] : pair[0]);
        }
        // Multi-value: cyclic repeat
        return src[idx % src.length].trim();
      }
    }
    return null;
  }

  static const _shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _fullMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  /// Month name series: Jan → Feb → Mar ... or January → February → March ...
  static String? _tryMonthSeries(List<String> src, int idx) {
    // Try short months
    final shortIndices = <int>[];
    for (final v in src) {
      final mIdx = _shortMonths.indexWhere((m) => m.toLowerCase() == v.trim().toLowerCase());
      if (mIdx == -1) { shortIndices.clear(); break; }
      shortIndices.add(mIdx);
    }
    if (shortIndices.isNotEmpty) {
      // Detect step
      final step = shortIndices.length > 1
          ? shortIndices[1] - shortIndices[0]
          : 1;
      final nextIdx = (shortIndices[0] + idx * step) % 12;
      return _shortMonths[nextIdx < 0 ? nextIdx + 12 : nextIdx];
    }

    // Try full months
    final fullIndices = <int>[];
    for (final v in src) {
      final mIdx = _fullMonths.indexWhere((m) => m.toLowerCase() == v.trim().toLowerCase());
      if (mIdx == -1) { fullIndices.clear(); break; }
      fullIndices.add(mIdx);
    }
    if (fullIndices.isNotEmpty) {
      final step = fullIndices.length > 1
          ? fullIndices[1] - fullIndices[0]
          : 1;
      final nextIdx = (fullIndices[0] + idx * step) % 12;
      return _fullMonths[nextIdx < 0 ? nextIdx + 12 : nextIdx];
    }

    return null;
  }

  static const _shortDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _fullDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  /// Day name series: Mon → Tue → Wed ...
  static String? _tryDaySeries(List<String> src, int idx) {
    // Try short days
    final shortIndices = <int>[];
    for (final v in src) {
      final dIdx = _shortDays.indexWhere((d) => d.toLowerCase() == v.trim().toLowerCase());
      if (dIdx == -1) { shortIndices.clear(); break; }
      shortIndices.add(dIdx);
    }
    if (shortIndices.isNotEmpty) {
      final step = shortIndices.length > 1
          ? shortIndices[1] - shortIndices[0]
          : 1;
      final nextIdx = (shortIndices[0] + idx * step) % 7;
      return _shortDays[nextIdx < 0 ? nextIdx + 7 : nextIdx];
    }

    // Try full days
    final fullIndices = <int>[];
    for (final v in src) {
      final dIdx = _fullDays.indexWhere((d) => d.toLowerCase() == v.trim().toLowerCase());
      if (dIdx == -1) { fullIndices.clear(); break; }
      fullIndices.add(dIdx);
    }
    if (fullIndices.isNotEmpty) {
      final step = fullIndices.length > 1
          ? fullIndices[1] - fullIndices[0]
          : 1;
      final nextIdx = (fullIndices[0] + idx * step) % 7;
      return _fullDays[nextIdx < 0 ? nextIdx + 7 : nextIdx];
    }

    return null;
  }

  /// Text with trailing number: "Item1", "Item2" → "Item3", "Item4"
  static String? _tryTextNumberSeries(List<String> src, int idx) {
    final regex = RegExp(r'^(.+?)(\d+)$');
    final prefixes = <String>[];
    final numbers = <int>[];

    for (final v in src) {
      final match = regex.firstMatch(v.trim());
      if (match == null) return null;
      prefixes.add(match.group(1)!);
      numbers.add(int.parse(match.group(2)!));
    }

    // All prefixes must be same
    if (prefixes.toSet().length != 1) return null;

    final prefix = prefixes[0];
    if (numbers.length == 1) {
      return '$prefix${numbers[0] + (idx - (src.length - 1))}';
    }

    final step = numbers.length > 1
        ? (numbers.last - numbers.first) / (numbers.length - 1)
        : 1;
    final nextNum = (numbers.first + (idx * step)).round();
    return '$prefix$nextNum';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FORMATTERS
  // ═══════════════════════════════════════════════════════════════════════════

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static int _colIndexFromStr(String colStr) {
    int col = 0;
    for (int i = 0; i < colStr.length; i++) {
      col = col * 26 + (colStr.codeUnitAt(i) - 64);
    }
    return col - 1;
  }

  static String _colStrFromIndex(int index) {
    String colStr = '';
    int c = index + 1;
    while (c > 0) {
      int rem = (c - 1) % 26;
      colStr = String.fromCharCode(65 + rem) + colStr;
      c = (c - rem) ~/ 26;
    }
    return colStr;
  }
}
