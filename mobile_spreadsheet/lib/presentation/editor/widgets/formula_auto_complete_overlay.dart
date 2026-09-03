import 'package:flutter/material.dart';

/// Data class for a formula completion suggestion
class FormulaSuggestion {
  final String name;
  final String signature;
  final String description;
  final String category;
  final Color categoryColor;

  const FormulaSuggestion({
    required this.name,
    required this.signature,
    required this.description,
    required this.category,
    required this.categoryColor,
  });
}

/// Persistent memory service tracking formula usage frequency & recent predictions
class FormulaMemoryService {
  static final Map<String, int> _usageFrequency = {
    'SUM': 15,
    'AVERAGE': 12,
    'COUNT': 8,
    'VLOOKUP': 6,
    'IF': 5,
  };

  static final List<String> _recentFormulas = [
    '=SUM(A1:A10)',
    '=AVERAGE(B1:B10)',
  ];

  static void recordUsage(String formulaName, [String? fullFormula]) {
    final cleanName = formulaName.toUpperCase().trim();
    _usageFrequency[cleanName] = (_usageFrequency[cleanName] ?? 0) + 1;

    if (fullFormula != null && fullFormula.isNotEmpty && fullFormula.startsWith('=')) {
      _recentFormulas.remove(fullFormula);
      _recentFormulas.insert(0, fullFormula);
      if (_recentFormulas.length > 5) {
        _recentFormulas.removeLast();
      }
    }
  }

  static int getFrequency(String formulaName) {
    return _usageFrequency[formulaName.toUpperCase().trim()] ?? 0;
  }

  static List<String> get recentFormulas => List.unmodifiable(_recentFormulas);
}

/// Catalog of supported spreadsheet formulas
class FormulaCatalog {
  static const List<FormulaSuggestion> all = [
    // Math Functions
    FormulaSuggestion(
      name: 'SUM',
      signature: 'SUM(number1, [number2], ...)',
      description: 'Adds all numbers in a range of cells',
      category: 'MATH',
      categoryColor: Color(0xFF2563EB),
    ),
    FormulaSuggestion(
      name: 'AVERAGE',
      signature: 'AVERAGE(number1, [number2], ...)',
      description: 'Calculates the arithmetic mean of arguments',
      category: 'STAT',
      categoryColor: Color(0xFF7C3AED),
    ),
    FormulaSuggestion(
      name: 'PRODUCT',
      signature: 'PRODUCT(number1, [number2], ...)',
      description: 'Multiplies all numbers given as arguments',
      category: 'MATH',
      categoryColor: Color(0xFF2563EB),
    ),
    FormulaSuggestion(
      name: 'POWER',
      signature: 'POWER(number, power)',
      description: 'Returns result of a number raised to a power',
      category: 'MATH',
      categoryColor: Color(0xFF2563EB),
    ),
    FormulaSuggestion(
      name: 'SQRT',
      signature: 'SQRT(number)',
      description: 'Calculates positive square root of a number',
      category: 'MATH',
      categoryColor: Color(0xFF2563EB),
    ),
    FormulaSuggestion(
      name: 'ABS',
      signature: 'ABS(number)',
      description: 'Returns absolute value of a number',
      category: 'MATH',
      categoryColor: Color(0xFF2563EB),
    ),
    FormulaSuggestion(
      name: 'ROUND',
      signature: 'ROUND(number, num_digits)',
      description: 'Rounds a number to a specified number of digits',
      category: 'MATH',
      categoryColor: Color(0xFF2563EB),
    ),
    FormulaSuggestion(
      name: 'MOD',
      signature: 'MOD(number, divisor)',
      description: 'Returns remainder after number is divided by divisor',
      category: 'MATH',
      categoryColor: Color(0xFF2563EB),
    ),

    // Statistical
    FormulaSuggestion(
      name: 'COUNT',
      signature: 'COUNT(value1, [value2], ...)',
      description: 'Counts cells containing numbers in range',
      category: 'STAT',
      categoryColor: Color(0xFF7C3AED),
    ),
    FormulaSuggestion(
      name: 'COUNTA',
      signature: 'COUNTA(value1, [value2], ...)',
      description: 'Counts cells that are not empty in range',
      category: 'STAT',
      categoryColor: Color(0xFF7C3AED),
    ),
    FormulaSuggestion(
      name: 'MAX',
      signature: 'MAX(number1, [number2], ...)',
      description: 'Returns maximum value in set of numbers',
      category: 'STAT',
      categoryColor: Color(0xFF7C3AED),
    ),
    FormulaSuggestion(
      name: 'MIN',
      signature: 'MIN(number1, [number2], ...)',
      description: 'Returns minimum value in set of numbers',
      category: 'STAT',
      categoryColor: Color(0xFF7C3AED),
    ),
    FormulaSuggestion(
      name: 'MEDIAN',
      signature: 'MEDIAN(number1, [number2], ...)',
      description: 'Returns median value of set of numbers',
      category: 'STAT',
      categoryColor: Color(0xFF7C3AED),
    ),

    // Lookup & Reference
    FormulaSuggestion(
      name: 'VLOOKUP',
      signature: 'VLOOKUP(lookup_val, table_arr, col_index, [range])',
      description: 'Looks for a value in leftmost column of a table',
      category: 'LOOKUP',
      categoryColor: Color(0xFF059669),
    ),
    FormulaSuggestion(
      name: 'HLOOKUP',
      signature: 'HLOOKUP(lookup_val, table_arr, row_index, [range])',
      description: 'Looks for a value in top row of a table',
      category: 'LOOKUP',
      categoryColor: Color(0xFF059669),
    ),
    FormulaSuggestion(
      name: 'XLOOKUP',
      signature: 'XLOOKUP(lookup_val, lookup_arr, return_arr)',
      description: 'Searches a range for a match and returns corresponding item',
      category: 'LOOKUP',
      categoryColor: Color(0xFF059669),
    ),
    FormulaSuggestion(
      name: 'INDEX',
      signature: 'INDEX(array, row_num, [col_num])',
      description: 'Returns value of element in a table at row and col',
      category: 'LOOKUP',
      categoryColor: Color(0xFF059669),
    ),
    FormulaSuggestion(
      name: 'MATCH',
      signature: 'MATCH(lookup_val, lookup_arr, [match_type])',
      description: 'Returns relative position of an item in a range',
      category: 'LOOKUP',
      categoryColor: Color(0xFF059669),
    ),

    // Text Functions
    FormulaSuggestion(
      name: 'CONCATENATE',
      signature: 'CONCATENATE(text1, [text2], ...)',
      description: 'Joins several text strings into one string',
      category: 'TEXT',
      categoryColor: Color(0xFFD97706),
    ),
    FormulaSuggestion(
      name: 'UPPER',
      signature: 'UPPER(text)',
      description: 'Converts a text string to all uppercase letters',
      category: 'TEXT',
      categoryColor: Color(0xFFD97706),
    ),
    FormulaSuggestion(
      name: 'LOWER',
      signature: 'LOWER(text)',
      description: 'Converts a text string to all lowercase letters',
      category: 'TEXT',
      categoryColor: Color(0xFFD97706),
    ),
    FormulaSuggestion(
      name: 'TRIM',
      signature: 'TRIM(text)',
      description: 'Removes all spaces from text except single spaces between words',
      category: 'TEXT',
      categoryColor: Color(0xFFD97706),
    ),
    FormulaSuggestion(
      name: 'LEN',
      signature: 'LEN(text)',
      description: 'Returns number of characters in a text string',
      category: 'TEXT',
      categoryColor: Color(0xFFD97706),
    ),

    // Logical Functions
    FormulaSuggestion(
      name: 'IF',
      signature: 'IF(logical_test, val_if_true, [val_if_false])',
      description: 'Checks whether condition is met, returns one value if TRUE, another if FALSE',
      category: 'LOGIC',
      categoryColor: Color(0xFFDC2626),
    ),
    FormulaSuggestion(
      name: 'IFS',
      signature: 'IFS(condition1, val1, [condition2, val2], ...)',
      description: 'Checks whether one or more conditions are met and returns corresponding value',
      category: 'LOGIC',
      categoryColor: Color(0xFFDC2626),
    ),
    FormulaSuggestion(
      name: 'AND',
      signature: 'AND(logical1, [logical2], ...)',
      description: 'Returns TRUE if all of its arguments are TRUE',
      category: 'LOGIC',
      categoryColor: Color(0xFFDC2626),
    ),
    FormulaSuggestion(
      name: 'OR',
      signature: 'OR(logical1, [logical2], ...)',
      description: 'Returns TRUE if any argument is TRUE',
      category: 'LOGIC',
      categoryColor: Color(0xFFDC2626),
    ),
    FormulaSuggestion(
      name: 'IFERROR',
      signature: 'IFERROR(value, val_if_error)',
      description: 'Returns val_if_error if expression evaluates to an error; otherwise value',
      category: 'LOGIC',
      categoryColor: Color(0xFFDC2626),
    ),

    // Date & Time Functions
    FormulaSuggestion(
      name: 'TODAY',
      signature: 'TODAY()',
      description: 'Returns current date formatted as date',
      category: 'DATE',
      categoryColor: Color(0xFF0284C7),
    ),
    FormulaSuggestion(
      name: 'NOW',
      signature: 'NOW()',
      description: 'Returns current date and time',
      category: 'DATE',
      categoryColor: Color(0xFF0284C7),
    ),
  ];

  /// Filter catalog by query and sort by usage frequency (Smart Prediction Memory)
  static List<FormulaSuggestion> getMatches(String query) {
    List<FormulaSuggestion> matches;
    if (query.isEmpty) {
      matches = List.from(all);
    } else {
      final cleanQuery = query.toUpperCase().trim();
      matches = all.where((item) {
        return item.name.toUpperCase().startsWith(cleanQuery) ||
            item.name.toUpperCase().contains(cleanQuery);
      }).toList();
    }

    // Sort by frequency memory (most frequently used at the top)
    matches.sort((a, b) {
      final freqA = FormulaMemoryService.getFrequency(a.name);
      final freqB = FormulaMemoryService.getFrequency(b.name);
      return freqB.compareTo(freqA);
    });

    return matches;
  }
}

/// Floating auto-complete suggestion overlay list widget
class FormulaAutoCompleteOverlay extends StatelessWidget {
  final String query;
  final ValueChanged<FormulaSuggestion> onSelected;

  const FormulaAutoCompleteOverlay({
    Key? key,
    required this.query,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final matches = FormulaCatalog.getMatches(query);

    if (matches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
      shadowColor: Colors.black12,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 110), // Micro compact height
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 1),
          physics: const BouncingScrollPhysics(),
          itemCount: matches.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
          itemBuilder: (context, index) {
            final suggestion = matches[index];
            final frequency = FormulaMemoryService.getFrequency(suggestion.name);
            final isFrequent = frequency > 5;

            return InkWell(
              onTap: () => onSelected(suggestion),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Micro tight padding
                child: Row(
                  children: [
                    // Micro Cute Category Badge (or Frequent Star Badge)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isFrequent ? const Color(0xFFFF9800) : suggestion.categoryColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        isFrequent ? '⭐ FREQUENT' : suggestion.category,
                        style: const TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Function Name + Signature
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                suggestion.name,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  suggestion.signature,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: Color(0xFF475569),
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            suggestion.description,
                            style: const TextStyle(
                              fontSize: 9.0,
                              color: Color(0xFF94A3B8),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),

                    // Micro Arrow Icon
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
