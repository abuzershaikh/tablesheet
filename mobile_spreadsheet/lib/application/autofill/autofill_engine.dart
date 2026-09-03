import '../../domain/entities/cell_range.dart';
import 'formula_shifter.dart';

class AutoFillEngine {
  /// Generates new cell data by extrapolating the [source] range over the [target] range.
  /// Note: [target] should encompass the ENTIRE range including the source, 
  /// or just the newly filled area. Usually, the UI selection expands, so [target] is the expanded range.
  /// But this method assumes [target] is strictly the NEW area to be filled, 
  /// OR we can just generate data for the entire target range and overwrite.
  /// Let's assume [target] is the new area ONLY, or we just safely overwrite everything in [target] except [source].
  /// Actually, easier: [target] is the total expanded range. We only generate values for cells NOT in [source].
  static Map<String, String> generateFillData(
      CellRange source, CellRange totalTarget, Map<String, String> currentData) {
    
    final Map<String, String> newData = {};
    final int dragDir = source.getDragDirection(totalTarget);

    if (dragDir == -1) return newData; // No drag

    final bool isVertical = dragDir == 0 || dragDir == 1; // 0=Up, 1=Down
    final bool isForward = dragDir == 1 || dragDir == 3;  // 1=Down, 3=Right

    if (isVertical) {
      // Dragging Up/Down. Process column by column.
      for (int col = source.minCol; col <= source.maxCol; col++) {
        // Extract source slice
        List<String> sourceSlice = [];
        List<int> sourceRows = [];
        for (int row = source.minRow; row <= source.maxRow; row++) {
          sourceSlice.add(currentData['$row:$col'] ?? '');
          sourceRows.add(row);
        }

        // Determine the target rows to fill
        List<int> targetRows = [];
        for (int row = totalTarget.minRow; row <= totalTarget.maxRow; row++) {
          if (row < source.minRow || row > source.maxRow) {
            targetRows.add(row);
          }
        }

        if (targetRows.isEmpty) continue;
        if (!isForward) targetRows = targetRows.reversed.toList();

        // Extrapolate
        final filledSlice = _extrapolate1D(sourceSlice, targetRows.length, isVertical, isForward);

        // Assign to newData
        for (int i = 0; i < targetRows.length; i++) {
          // If dragging up (not forward), filledSlice must be assigned bottom-up
          newData['${targetRows[i]}:$col'] = filledSlice[i];
        }
      }
    } else {
      // Dragging Left/Right. Process row by row.
      for (int row = source.minRow; row <= source.maxRow; row++) {
        List<String> sourceSlice = [];
        for (int col = source.minCol; col <= source.maxCol; col++) {
          sourceSlice.add(currentData['$row:$col'] ?? '');
        }

        List<int> targetCols = [];
        for (int col = totalTarget.minCol; col <= totalTarget.maxCol; col++) {
          if (col < source.minCol || col > source.maxCol) {
            targetCols.add(col);
          }
        }

        if (targetCols.isEmpty) continue;
        if (!isForward) targetCols = targetCols.reversed.toList();

        final filledSlice = _extrapolate1D(sourceSlice, targetCols.length, isVertical, isForward);

        for (int i = 0; i < targetCols.length; i++) {
          newData['$row:${targetCols[i]}'] = filledSlice[i];
        }
      }
    }

    return newData;
  }

  static List<String> _extrapolate1D(List<String> source, int count, bool isVertical, bool isForward) {
    if (source.isEmpty) return List.filled(count, '');
    
    // 1. Formula Detector
    if (source.length == 1 && source.first.startsWith('=')) {
      return _generateFormulas(source.first, count, isVertical, isForward);
    } else if (source.every((s) => s.startsWith('='))) {
      // Multiple formulas: just repeat them, but shift according to total offset
      return _generatePatternedFormulas(source, count, isVertical, isForward);
    }

    // 2. Numeric Sequence Detector
    if (source.every((s) => double.tryParse(s) != null)) {
      if (source.length == 1) {
        // Single number -> constant copy
        return List.filled(count, source.first);
      } else {
        // Multiple numbers -> arithmetic sequence
        final nums = source.map((s) => double.parse(s)).toList();
        final diff = nums[1] - nums[0];
        // Check if constant diff
        bool isArithmetic = true;
        for (int i = 1; i < nums.length - 1; i++) {
          if ((nums[i + 1] - nums[i] - diff).abs() > 0.0001) {
            isArithmetic = false;
            break;
          }
        }
        
        if (isArithmetic) {
          List<String> res = [];
          double current = nums.last;
          double step = isForward ? diff : -diff; // if dragging backward, we subtract diff?
          // Wait, if source is [2, 4] and we drag UP, the next should be 0, -2.
          // In our loop, targetRows are reversed for backward drag, meaning we generate the closest cell first.
          // So if backward, step = nums.first - nums[1] = -diff.
          step = isForward ? diff : (nums.first - nums[1]);
          current = isForward ? nums.last : nums.first;

          for (int i = 0; i < count; i++) {
            current += step;
            // Format to drop .0 if integer
            String s = current.toString();
            if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
            res.add(s);
          }
          return res;
        }
      }
    }

    // 3. AlphaNumeric Sequence (e.g. "Item 1", "ABC001")
    if (source.length >= 1) {
      final alphaNumRegex = RegExp(r'^(.+?)(\d+)$');
      bool allMatch = true;
      String? prefix;
      List<int> numbers = [];

      for (var s in source) {
        final match = alphaNumRegex.firstMatch(s);
        if (match == null) {
          allMatch = false;
          break;
        }
        if (prefix == null) {
          prefix = match.group(1);
        } else if (prefix != match.group(1)) {
          allMatch = false;
          break;
        }
        numbers.add(int.parse(match.group(2)!));
      }

      if (allMatch && prefix != null) {
        int diff = 1; // Default diff for single item is +1 for alphanumeric! (Unlike pure numbers)
        if (numbers.length > 1) {
          diff = numbers[1] - numbers[0];
        }

        List<String> res = [];
        int step = isForward ? diff : -diff;
        if (!isForward && numbers.length > 1) {
           step = numbers.first - numbers[1];
        }
        int current = isForward ? numbers.last : numbers.first;
        
        // Find padding (e.g. 001)
        final firstMatch = alphaNumRegex.firstMatch(source.first)!;
        final numStrLen = firstMatch.group(2)!.length;

        for (int i = 0; i < count; i++) {
          current += step;
          String numStr = current.toString();
          if (numStr.length < numStrLen) {
            numStr = numStr.padLeft(numStrLen, '0');
          }
          res.add('$prefix$numStr');
        }
        return res;
      }
    }

    // 4. Date/Weekday/Month (Simplified for now)
    final weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final months = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december'];
    final shortMonths = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

    int getIndex(List<String> list, String val) => list.indexOf(val.toLowerCase());

    if (source.length == 1) {
      final s = source.first;
      if (getIndex(weekdays, s) != -1) return _generateListPattern(weekdays, s, count, isForward);
      if (getIndex(months, s) != -1) return _generateListPattern(months, s, count, isForward);
      if (getIndex(shortMonths, s) != -1) return _generateListPattern(shortMonths, s, count, isForward);
    }

    // 5. Fallback: Constant Copy (Repeat source)
    List<String> res = [];
    for (int i = 0; i < count; i++) {
      // If dragging backwards, we might want to iterate source backwards, but repeating is fine.
      res.add(source[i % source.length]);
    }
    return res;
  }

  static List<String> _generateListPattern(List<String> dictionary, String start, int count, bool isForward) {
    int idx = dictionary.indexOf(start.toLowerCase());
    bool isCapitalized = start.isNotEmpty && start[0].toUpperCase() == start[0];
    
    List<String> res = [];
    int step = isForward ? 1 : -1;
    for (int i = 0; i < count; i++) {
      idx = (idx + step) % dictionary.length;
      if (idx < 0) idx += dictionary.length;
      String word = dictionary[idx];
      if (isCapitalized) {
        word = word[0].toUpperCase() + word.substring(1);
      }
      res.add(word);
    }
    return res;
  }

  static List<String> _generateFormulas(String baseFormula, int count, bool isVertical, bool isForward) {
    List<String> res = [];
    for (int i = 1; i <= count; i++) {
      int offset = isForward ? i : -i;
      int rOff = isVertical ? offset : 0;
      int cOff = isVertical ? 0 : offset;
      res.add(FormulaShifter.shiftFormula(baseFormula, rOff, cOff));
    }
    return res;
  }

  static List<String> _generatePatternedFormulas(List<String> source, int count, bool isVertical, bool isForward) {
    List<String> res = [];
    // E.g., source = [A1, A2]. Length = 2. 
    // We want the next to be A3, A4 (which is source[0] shifted by 2, source[1] shifted by 2)
    int sourceLen = source.length;
    for (int i = 0; i < count; i++) {
      int blockIndex = i ~/ sourceLen; // 0 for first block, 1 for second...
      int itemIndex = i % sourceLen;
      
      // Shift amount = (blockIndex + 1) * sourceLen
      int shiftAmt = (blockIndex + 1) * sourceLen;
      if (!isForward) shiftAmt = -shiftAmt;

      int rOff = isVertical ? shiftAmt : 0;
      int cOff = isVertical ? 0 : shiftAmt;

      res.add(FormulaShifter.shiftFormula(source[itemIndex], rOff, cOff));
    }
    return res;
  }
}
