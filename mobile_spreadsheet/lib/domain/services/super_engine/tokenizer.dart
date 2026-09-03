enum TokenType {
  number,
  string,
  identifier,  // e.g., A1, SUM, MAX
  range,       // e.g., A1:B10 (usually generated during parsing from A1 : B10)
  plus,        // +
  minus,       // -
  multiply,    // *
  divide,      // /
  power,       // ^
  percent,     // %
  concat,      // &
  equal,       // =
  notEqual,    // <>
  lessThan,    // <
  lessThanOrEqual, // <=
  greaterThan, // >
  greaterThanOrEqual, // >=
  comma,       // ,
  colon,       // :
  lParen,      // (
  rParen,      // )
  lBrace,      // {
  rBrace,      // }
  semicolon,   // ;
  error,       // e.g. #DIV/0!
  eof,
}

class Token {
  final TokenType type;
  final String lexeme;
  final int position;

  const Token(this.type, this.lexeme, this.position);

  @override
  String toString() => 'Token($type, "$lexeme")';
}

class Tokenizer {
  final String source;
  int _position = 0;

  Tokenizer(this.source);

  bool get _isAtEnd => _position >= source.length;

  String get _currentChar => _isAtEnd ? '\x00' : source[_position];

  void _advance() => _position++;

  List<Token> tokenize() {
    final tokens = <Token>[];
    if (source.startsWith('=')) {
      _advance(); // Skip the leading '='
    } else {
      // If it doesn't start with '=', it's a plain string or number
      final numValue = double.tryParse(source);
      if (numValue != null) {
        tokens.add(Token(TokenType.number, source, 0));
      } else {
        tokens.add(Token(TokenType.string, source, 0));
      }
      tokens.add(Token(TokenType.eof, '', source.length));
      return tokens;
    }

    while (!_isAtEnd) {
      final c = _currentChar;

      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        _advance();
        continue;
      }

      final startPos = _position;

      switch (c) {
        case '+':
          _advance();
          tokens.add(Token(TokenType.plus, c, startPos));
          break;
        case '-':
          _advance();
          tokens.add(Token(TokenType.minus, c, startPos));
          break;
        case '*':
          _advance();
          tokens.add(Token(TokenType.multiply, c, startPos));
          break;
        case '/':
          _advance();
          tokens.add(Token(TokenType.divide, c, startPos));
          break;
        case '^':
          _advance();
          tokens.add(Token(TokenType.power, c, startPos));
          break;
        case '%':
          _advance();
          tokens.add(Token(TokenType.percent, c, startPos));
          break;
        case '&':
          _advance();
          tokens.add(Token(TokenType.concat, c, startPos));
          break;
        case '=':
          _advance();
          tokens.add(Token(TokenType.equal, c, startPos));
          break;
        case '<':
          _advance();
          if (_currentChar == '>') {
            _advance();
            tokens.add(Token(TokenType.notEqual, '<>', startPos));
          } else if (_currentChar == '=') {
            _advance();
            tokens.add(Token(TokenType.lessThanOrEqual, '<=', startPos));
          } else {
            tokens.add(Token(TokenType.lessThan, '<', startPos));
          }
          break;
        case '>':
          _advance();
          if (_currentChar == '=') {
            _advance();
            tokens.add(Token(TokenType.greaterThanOrEqual, '>=', startPos));
          } else {
            tokens.add(Token(TokenType.greaterThan, '>', startPos));
          }
          break;
        case '(':
          _advance();
          tokens.add(Token(TokenType.lParen, c, startPos));
          break;
        case ')':
          _advance();
          tokens.add(Token(TokenType.rParen, c, startPos));
          break;
        case '{':
          _advance();
          tokens.add(Token(TokenType.lBrace, c, startPos));
          break;
        case '}':
          _advance();
          tokens.add(Token(TokenType.rBrace, c, startPos));
          break;
        case ',':
          _advance();
          tokens.add(Token(TokenType.comma, c, startPos));
          break;
        case ':':
          _advance();
          tokens.add(Token(TokenType.colon, c, startPos));
          break;
        case ';':
          _advance();
          tokens.add(Token(TokenType.semicolon, c, startPos));
          break;
        case '"':
          tokens.add(_scanString());
          break;
        case '#':
          tokens.add(_scanError());
          break;
        default:
          if (_isDigit(c) || c == '.') {
            tokens.add(_scanNumber());
          } else if (_isAlpha(c) || c == '_' || c == '\$') {
            tokens.add(_scanIdentifier());
          } else {
            // Unknown character
            _advance();
          }
          break;
      }
    }

    tokens.add(Token(TokenType.eof, '', _position));
    return tokens;
  }

  bool _isDigit(String c) {
    if (c.isEmpty) return false;
    final code = c.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  bool _isAlpha(String c) {
    if (c.isEmpty) return false;
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  Token _scanNumber() {
    final start = _position;
    bool hasDot = false;
    bool hasE = false;

    while (!_isAtEnd) {
      final c = _currentChar;
      if (_isDigit(c)) {
        _advance();
      } else if (c == '.' && !hasDot && !hasE) {
        hasDot = true;
        _advance();
      } else if ((c == 'E' || c == 'e') && !hasE) {
        hasE = true;
        _advance();
        if (_currentChar == '+' || _currentChar == '-') {
          _advance();
        }
      } else {
        break;
      }
    }

    final lexeme = source.substring(start, _position);
    return Token(TokenType.number, lexeme, start);
  }

  Token _scanIdentifier() {
    final start = _position;
    while (!_isAtEnd && (_isAlpha(_currentChar) || _isDigit(_currentChar) || _currentChar == '_' || _currentChar == '\$')) {
      _advance();
    }
    return Token(TokenType.identifier, source.substring(start, _position), start);
  }

  Token _scanString() {
    final start = _position;
    _advance(); // Skip opening quote
    while (!_isAtEnd && _currentChar != '"') {
      _advance();
    }
    if (!_isAtEnd) _advance(); // Skip closing quote
    
    // Excel strings un-escape "" to "
    // But lexer just returns the raw string inside quotes
    final lexeme = source.substring(start + 1, _position > start ? _position - 1 : _position);
    return Token(TokenType.string, lexeme, start);
  }

  Token _scanError() {
    final start = _position;
    while (!_isAtEnd && _currentChar != ' ' && _currentChar != ',' && _currentChar != ')') {
      _advance();
      if (source.substring(start, _position).endsWith('!') || source.substring(start, _position).endsWith('?')) {
        break;
      }
    }
    return Token(TokenType.error, source.substring(start, _position), start);
  }
}
