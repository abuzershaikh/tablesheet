import 'tokenizer.dart';

abstract class AstNode {
  const AstNode();
}

class NumberNode extends AstNode {
  final double value;
  const NumberNode(this.value);
}

class StringNode extends AstNode {
  final String value;
  const StringNode(this.value);
}

class BooleanNode extends AstNode {
  final bool value;
  const BooleanNode(this.value);
}

class ErrorNode extends AstNode {
  final String error;
  const ErrorNode(this.error);
}

class CellReferenceNode extends AstNode {
  final String rawName;
  final int row;
  final int col;
  final bool isAbsoluteRow;
  final bool isAbsoluteCol;
  final String? sheetName;

  const CellReferenceNode({
    required this.rawName,
    required this.row,
    required this.col,
    this.isAbsoluteRow = false,
    this.isAbsoluteCol = false,
    this.sheetName,
  });

  String get cellName => rawName;

  String toRefString() {
    // Helper to generate col string A, B, ..., Z, AA, AB...
    String colStr = '';
    int i = col;
    while (i >= 0) {
      colStr = String.fromCharCode((i % 26) + 65) + colStr;
      i = (i ~/ 26) - 1;
    }
    final rowStr = (row + 1).toString();
    final cPrefix = isAbsoluteCol ? '\$' : '';
    final rPrefix = isAbsoluteRow ? '\$' : '';
    final sheetPrefix = sheetName != null ? '$sheetName!' : '';
    return '$sheetPrefix$cPrefix$colStr$rPrefix$rowStr';
  }
}

class RangeReferenceNode extends AstNode {
  final CellReferenceNode topLeft;
  final CellReferenceNode bottomRight;

  const RangeReferenceNode(this.topLeft, this.bottomRight);

  String get topLeftStr => topLeft.toRefString();
  String get bottomRightStr => bottomRight.toRefString();
}

class BinaryOpNode extends AstNode {
  final TokenType operator;
  final AstNode left;
  final AstNode right;
  const BinaryOpNode(this.left, this.operator, this.right);
}

class UnaryOpNode extends AstNode {
  final TokenType operator;
  final AstNode operand;
  const UnaryOpNode(this.operator, this.operand);
}

class FunctionNode extends AstNode {
  final String name;
  final List<AstNode> arguments;
  const FunctionNode(this.name, this.arguments);
}

class ArrayNode extends AstNode {
  final List<List<AstNode>> rows;
  const ArrayNode(this.rows);
}

class BlankNode extends AstNode {
  const BlankNode();
}

extension AstStringifier on AstNode {
  String toFormulaString() {
    if (this is NumberNode) {
      final val = (this as NumberNode).value;
      if (val == val.truncateToDouble() && val.abs() < 9007199254740992) {
        return val.toInt().toString();
      }
      return val.toString();
    }
    if (this is StringNode) {
      return '"${(this as StringNode).value}"';
    }
    if (this is BooleanNode) {
      return (this as BooleanNode).value ? 'TRUE' : 'FALSE';
    }
    if (this is ErrorNode) {
      return (this as ErrorNode).error;
    }
    if (this is BlankNode) {
      return '';
    }
    if (this is CellReferenceNode) {
      return (this as CellReferenceNode).toRefString();
    }
    if (this is RangeReferenceNode) {
      final range = this as RangeReferenceNode;
      return '${range.topLeft.toRefString()}:${range.bottomRight.toRefString()}';
    }
    if (this is BinaryOpNode) {
      final bin = this as BinaryOpNode;
      return '${bin.left.toFormulaString()}${_tokenToString(bin.operator)}${bin.right.toFormulaString()}';
    }
    if (this is UnaryOpNode) {
      final un = this as UnaryOpNode;
      if (un.operator == TokenType.percent) {
        return '${un.operand.toFormulaString()}%';
      }
      return '${_tokenToString(un.operator)}${un.operand.toFormulaString()}';
    }
    if (this is FunctionNode) {
      final fn = this as FunctionNode;
      final argsStr = fn.arguments.map((a) => a.toFormulaString()).join(',');
      return '${fn.name}($argsStr)';
    }
    if (this is ArrayNode) {
      final arr = this as ArrayNode;
      final rowsStr = arr.rows.map((r) => r.map((c) => c.toFormulaString()).join(',')).join(';');
      return '{$rowsStr}';
    }
    return '';
  }

  String _tokenToString(TokenType type) {
    switch (type) {
      case TokenType.plus: return '+';
      case TokenType.minus: return '-';
      case TokenType.multiply: return '*';
      case TokenType.divide: return '/';
      case TokenType.power: return '^';
      case TokenType.concat: return '&';
      case TokenType.equal: return '=';
      case TokenType.notEqual: return '<>';
      case TokenType.lessThan: return '<';
      case TokenType.lessThanOrEqual: return '<=';
      case TokenType.greaterThan: return '>';
      case TokenType.greaterThanOrEqual: return '>=';
      case TokenType.colon: return ':';
      default: return '';
    }
  }
}
