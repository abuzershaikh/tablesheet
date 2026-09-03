import 'ast.dart';
import 'tokenizer.dart';

class Parser {
  final List<Token> tokens;
  int _pos = 0;

  Parser(this.tokens);

  Token get _current => tokens[_pos];
  Token get _previous => tokens[_pos > 0 ? _pos - 1 : 0];
  bool get _isAtEnd => _current.type == TokenType.eof;

  AstNode parse() {
    return _parseExpression(0);
  }

  void _advance() {
    if (!_isAtEnd) _pos++;
  }

  bool _match(TokenType type) {
    if (_current.type == type) {
      _advance();
      return true;
    }
    return false;
  }

  void _consume(TokenType type, String message) {
    if (_current.type == type) {
      _advance();
      return;
    }
    throw FormatException(message);
  }

  int _getPrecedence(TokenType type) {
    switch (type) {
      case TokenType.equal:
      case TokenType.notEqual:
      case TokenType.lessThan:
      case TokenType.lessThanOrEqual:
      case TokenType.greaterThan:
      case TokenType.greaterThanOrEqual:
        return 1;
      case TokenType.concat:
        return 2;
      case TokenType.plus:
      case TokenType.minus:
        return 3;
      case TokenType.multiply:
      case TokenType.divide:
        return 4;
      case TokenType.power:
        return 5;
      case TokenType.percent:
        return 6;
      case TokenType.colon:
        return 7;
      default:
        return 0;
    }
  }

  AstNode _parseExpression(int precedence) {
    AstNode left = _parsePrefix();

    while (!_isAtEnd && precedence < _getPrecedence(_current.type)) {
      final op = _current.type;
      _advance();
      
      if (op == TokenType.colon) {
        // Range operator logic A1:B2
        if (left is CellReferenceNode) {
          final right = _parseExpression(_getPrecedence(op));
          if (right is CellReferenceNode) {
            left = RangeReferenceNode(left, right);
            continue;
          }
        }
        throw const FormatException("Invalid range notation");
      } else if (op == TokenType.percent) {
        // Postfix operator
        left = UnaryOpNode(op, left);
      } else {
        final right = _parseExpression(_getPrecedence(op));
        left = BinaryOpNode(left, op, right);
      }
    }

    return left;
  }

  AstNode _parsePrefix() {
    if (_match(TokenType.plus) || _match(TokenType.minus)) {
      final op = _previous.type;
      final operand = _parseExpression(6); // high precedence for unary
      return UnaryOpNode(op, operand);
    }

    if (_match(TokenType.lParen)) {
      final expr = _parseExpression(0);
      _consume(TokenType.rParen, "Expected ')' after expression");
      return expr;
    }

    if (_match(TokenType.number)) {
      return NumberNode(double.parse(_previous.lexeme));
    }

    if (_match(TokenType.string)) {
      return StringNode(_previous.lexeme);
    }

    if (_match(TokenType.error)) {
      return ErrorNode(_previous.lexeme);
    }

    if (_match(TokenType.identifier)) {
      final name = _previous.lexeme;
      
      // Check if it's a function call
      if (_match(TokenType.lParen)) {
        final args = <AstNode>[];
        if (_current.type != TokenType.rParen) {
          do {
            if (_current.type == TokenType.comma || _current.type == TokenType.rParen) {
              args.add(const BlankNode());
            } else {
              args.add(_parseExpression(0));
            }
          } while (_match(TokenType.comma));
        }
        _consume(TokenType.rParen, "Expected ')' after arguments");
        return FunctionNode(name, args);
      }
      
      // If it's TRUE or FALSE
      if (name.toUpperCase() == 'TRUE') return const BooleanNode(true);
      if (name.toUpperCase() == 'FALSE') return const BooleanNode(false);
      
      // Otherwise, it's a cell reference like A1, $A$1, A$1, $A1
      return _buildCellRefNode(name);
    }
    
    // Array literals {1,2;3,4}
    if (_match(TokenType.lBrace)) {
      final rows = <List<AstNode>>[];
      do {
        final row = <AstNode>[];
        do {
          row.add(_parseExpression(0));
        } while (_match(TokenType.comma));
        rows.add(row);
      } while (_match(TokenType.semicolon));
      _consume(TokenType.rBrace, "Expected '}' after array literal");
      return ArrayNode(rows);
    }

    throw FormatException("Unexpected token: ${_current.lexeme}");
  }

  static final RegExp _cellRefRegExp = RegExp(r'^(\$?)([A-Z]+)(\$?)([0-9]+)$', caseSensitive: false);

  static AstNode _buildCellRefNode(String name) {
    final match = _cellRefRegExp.firstMatch(name);
    if (match != null) {
      final isAbsCol = match.group(1) == '\$';
      final colStr = match.group(2)!.toUpperCase();
      final isAbsRow = match.group(3) == '\$';
      final rowStr = match.group(4)!;

      int col = 0;
      for (int i = 0; i < colStr.length; i++) {
        col = col * 26 + (colStr.codeUnitAt(i) - 64);
      }
      col = col - 1; // 0-indexed
      final row = (int.tryParse(rowStr) ?? 1) - 1; // 0-indexed

      return CellReferenceNode(
        rawName: name,
        row: row,
        col: col,
        isAbsoluteRow: isAbsRow,
        isAbsoluteCol: isAbsCol,
      );
    }

    return CellReferenceNode(
      rawName: name,
      row: 0,
      col: 0,
      isAbsoluteRow: false,
      isAbsoluteCol: false,
    );
  }
}
