/// Analyzes formulas to determine if they need progress indication
class FormulaAnalyzer {
  // Threshold for showing progress
  static const int SMALL_ARRAY_THRESHOLD = 10000;    // < 100x100
  static const int MEDIUM_ARRAY_THRESHOLD = 100000;  // < 316x316
  static const int LARGE_ARRAY_THRESHOLD = 1000000;  // Up to 1000x1000

  /// Check if formula is a large array formula that needs progress
  static bool needsProgress(String formula) {
    if (formula.isEmpty) return false;
    
    final upperFormula = formula.toUpperCase();
    
    // Check for array functions
    final arrayFunctions = [
      'MAKEARRAY',
      'SEQUENCE',
      'RANDARRAY',
      'FILTER',
      'SORT',
      'SORTBY',
      'UNIQUE',
    ];
    
    for (final func in arrayFunctions) {
      if (upperFormula.contains(func)) {
        final estimatedSize = _estimateArraySize(formula, func);
        if (estimatedSize >= SMALL_ARRAY_THRESHOLD) {
          return true;
        }
      }
    }
    
    return false;
  }

  /// Get progress message based on formula
  static String getProgressMessage(String formula) {
    final upperFormula = formula.toUpperCase();
    
    if (upperFormula.contains('MAKEARRAY')) {
      return 'Creating large array...';
    } else if (upperFormula.contains('SEQUENCE')) {
      return 'Generating sequence...';
    } else if (upperFormula.contains('RANDARRAY')) {
      return 'Generating random values...';
    } else if (upperFormula.contains('FILTER')) {
      return 'Filtering data...';
    } else if (upperFormula.contains('SORT')) {
      return 'Sorting data...';
    } else if (upperFormula.contains('MAP')) {
      return 'Mapping values...';
    } else if (upperFormula.contains('BYROW') || upperFormula.contains('BYCOL')) {
      return 'Processing rows/columns...';
    } else if (upperFormula.contains('LET')) {
      return 'Evaluating complex formula...';
    }
    
    return 'Processing formula...';
  }

  /// Estimate array size from formula (rough estimate)
  static int _estimateArraySize(String formula, String function) {
    try {
      // Try to extract numeric arguments
      final regex = RegExp('$function\\s*\\(\\s*(\\d+)\\s*,\\s*(\\d+)', 
                           caseSensitive: false);
      final match = regex.firstMatch(formula);
      
      if (match != null && match.groupCount >= 2) {
        final rows = int.tryParse(match.group(1) ?? '0') ?? 0;
        final cols = int.tryParse(match.group(2) ?? '0') ?? 0;
        return rows * cols;
      }
      
      // Default to medium size if can't parse
      return MEDIUM_ARRAY_THRESHOLD;
    } catch (e) {
      return MEDIUM_ARRAY_THRESHOLD;
    }
  }

  /// Determine if we should show determinate (%) or indeterminate progress
  static bool shouldShowPercentage(String formula) {
    final upperFormula = formula.toUpperCase();
    
    // These functions can show percentage
    if (upperFormula.contains('MAKEARRAY') ||
        upperFormula.contains('SEQUENCE') ||
        upperFormula.contains('RANDARRAY')) {
      return true;
    }
    
    // These are harder to track progress
    return false;
  }

  /// Estimate processing time in seconds (very rough)
  static double estimateProcessingTime(String formula) {
    final size = _estimateArraySize(formula, 'MAKEARRAY');
    
    if (size < 10000) return 0.1;
    if (size < 50000) return 0.5;
    if (size < 100000) return 1.0;
    if (size < 500000) return 3.0;
    return 10.0; // 1M cells
  }
}
