/// Strictly typed values for the Super Engine
abstract class CellValue {
  const CellValue();

  /// String representation of the value (for rendering)
  String get displayValue;

  /// Whether the value is considered an error
  bool get isError => false;

  /// Whether the value is completely empty
  bool get isBlank => false;
}

class NumberValue extends CellValue {
  final double value;
  const NumberValue(this.value);

  @override
  String get displayValue {
    if (value == value.toInt()) return value.toInt().toString();
    return value.toString();
  }
}

class StringValue extends CellValue {
  final String value;
  const StringValue(this.value);

  @override
  String get displayValue => value;
}

class BooleanValue extends CellValue {
  final bool value;
  const BooleanValue(this.value);

  @override
  String get displayValue => value ? 'TRUE' : 'FALSE';
}

class BlankValue extends CellValue {
  const BlankValue();

  @override
  String get displayValue => '';

  @override
  bool get isBlank => true;
}

class ErrorValue extends CellValue {
  final String type;
  final String message;
  const ErrorValue(this.type, [this.message = '']);

  static const divByZero = ErrorValue('#DIV/0!', 'Division by zero');
  static const valueError = ErrorValue('#VALUE!', 'Wrong data type');
  static const refError = ErrorValue('#REF!', 'Invalid cell reference');
  static const nameError = ErrorValue('#NAME?', 'Unknown function or variable');
  static const numError = ErrorValue('#NUM!', 'Invalid numeric value');
  static const naError = ErrorValue('#N/A', 'Value not available');
  static const spillError = ErrorValue('#SPILL!', 'Spill range is not empty');

  @override
  String get displayValue => type;

  @override
  bool get isError => true;
}

class ArrayValue extends CellValue {
  final List<List<CellValue>> matrix;
  const ArrayValue(this.matrix);

  @override
  String get displayValue {
    if (matrix.isEmpty || matrix[0].isEmpty) return '';
    return matrix[0][0].displayValue;
  }
}
