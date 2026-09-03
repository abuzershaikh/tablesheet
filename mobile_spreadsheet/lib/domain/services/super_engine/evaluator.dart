import 'ast.dart';
import 'cell_value.dart';
import 'tokenizer.dart';

typedef CellProvider = CellValue Function(String cellId);
typedef RangeProvider = List<List<CellValue>> Function(String topLeft, String bottomRight);

class Evaluator {
  final CellProvider getCell;
  final RangeProvider getRange;

  Evaluator(this.getCell, this.getRange);

  CellValue evaluate(AstNode node) {
    if (node is NumberNode) return NumberValue(node.value);
    if (node is StringNode) return StringValue(node.value);
    if (node is BooleanNode) return BooleanValue(node.value);
    if (node is ErrorNode) return ErrorValue(node.error);
    
    if (node is CellReferenceNode) {
      return getCell(node.cellName);
    }
    
    if (node is RangeReferenceNode) {
      return ArrayValue(getRange(node.topLeftStr, node.bottomRightStr));
    }

    if (node is ArrayNode) {
      final matrix = <List<CellValue>>[];
      for (final row in node.rows) {
        final rowVals = <CellValue>[];
        for (final expr in row) {
          rowVals.add(evaluate(expr));
        }
        matrix.add(rowVals);
      }
      return ArrayValue(matrix);
    }

    if (node is UnaryOpNode) {
      final operand = evaluate(node.operand);
      if (operand is ErrorValue) return operand;
      
      if (node.operator == TokenType.minus) {
        final num = _toNumber(operand);
        if (num == null) return ErrorValue.valueError;
        return NumberValue(-num);
      } else if (node.operator == TokenType.plus) {
        final num = _toNumber(operand);
        if (num == null) return ErrorValue.valueError;
        return NumberValue(num);
      } else if (node.operator == TokenType.percent) {
        final num = _toNumber(operand);
        if (num == null) return ErrorValue.valueError;
        return NumberValue(num / 100);
      }
    }

    if (node is BinaryOpNode) {
      final left = evaluate(node.left);
      if (left is ErrorValue) return left;
      
      final right = evaluate(node.right);
      if (right is ErrorValue) return right;

      if (node.operator == TokenType.concat) {
        return StringValue(left.displayValue + right.displayValue);
      }

      if (_isComparison(node.operator)) {
        return _evaluateComparison(left, right, node.operator);
      }

      final lNum = _toNumber(left);
      final rNum = _toNumber(right);
      if (lNum == null || rNum == null) return ErrorValue.valueError;

      switch (node.operator) {
        case TokenType.plus: return NumberValue(lNum + rNum);
        case TokenType.minus: return NumberValue(lNum - rNum);
        case TokenType.multiply: return NumberValue(lNum * rNum);
        case TokenType.divide:
          if (rNum == 0) return ErrorValue.divByZero;
          return NumberValue(lNum / rNum);
        case TokenType.power:
          // Implement power if needed, using dart:math pow
          return ErrorValue.valueError; // Simplified for now
        default:
          return ErrorValue.valueError;
      }
    }

    if (node is FunctionNode) {
      // Stub for function registry
      return ErrorValue.nameError;
    }

    return ErrorValue.valueError;
  }

  bool _isComparison(TokenType op) {
    return op == TokenType.equal || op == TokenType.notEqual ||
           op == TokenType.lessThan || op == TokenType.lessThanOrEqual ||
           op == TokenType.greaterThan || op == TokenType.greaterThanOrEqual;
  }

  CellValue _evaluateComparison(CellValue left, CellValue right, TokenType op) {
    // Simplified comparison logic
    if (op == TokenType.equal) {
      return BooleanValue(left.displayValue == right.displayValue);
    }
    if (op == TokenType.notEqual) {
      return BooleanValue(left.displayValue != right.displayValue);
    }
    return ErrorValue.valueError;
  }

  double? _toNumber(CellValue val) {
    if (val is NumberValue) return val.value;
    if (val is BooleanValue) return val.value ? 1.0 : 0.0;
    if (val is BlankValue) return 0.0;
    if (val is StringValue) return double.tryParse(val.value);
    return null;
  }
}
