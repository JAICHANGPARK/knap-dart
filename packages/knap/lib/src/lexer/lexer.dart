import '../errors/exceptions.dart';
import '../tokens/token.dart';

class KnapLexer {
  final String source;
  int _start = 0;
  int _current = 0;
  int _line = 1;
  int _column = 1;
  int _startColumn = 1;

  bool _inTag = false;
  bool _inVariable = false;

  KnapLexer(this.source);

  List<Token> scanTokens() {
    final tokens = <Token>[];

    while (!_isAtEnd()) {
      _start = _current;
      _startColumn = _column;

      if (_inTag || _inVariable) {
        _scanInsideTag(tokens);
      } else {
        _scanOutsideTag(tokens);
      }
    }

    tokens.add(
      Token(
        type: TokenType.eof,
        lexeme: '',
        location: SourceLocation(
          offset: _current,
          line: _line,
          column: _column,
        ),
      ),
    );

    // Post-process whitespace trimming:
    return _applyWhitespaceTrimming(tokens);
  }

  void _scanOutsideTag(List<Token> tokens) {
    while (!_isAtEnd()) {
      if (_peek() == '{' && (_peekNext() == '{' || _peekNext() == '%')) {
        break;
      }
      _advance();
    }

    if (_current > _start) {
      final text = source.substring(_start, _current);
      tokens.add(
        Token(
          type: TokenType.text,
          lexeme: text,
          literal: text,
          location: SourceLocation(
            offset: _start,
            line: _line,
            column: _startColumn,
          ),
        ),
      );
    }

    if (_isAtEnd()) return;

    _start = _current;
    _startColumn = _column;

    if (_peek() == '{' && _peekNext() == '{') {
      _advance(); // {
      _advance(); // {
      var trimLeft = false;
      if (_peek() == '-') {
        _advance();
        trimLeft = true;
      }
      _inVariable = true;
      tokens.add(
        Token(
          type: TokenType.variableStart,
          lexeme: trimLeft ? '{{-' : '{{',
          location: SourceLocation(
            offset: _start,
            line: _line,
            column: _startColumn,
          ),
          trimLeft: trimLeft,
        ),
      );
    } else if (_peek() == '{' && _peekNext() == '%') {
      _advance(); // {
      _advance(); // %
      var trimLeft = false;
      if (_peek() == '-') {
        _advance();
        trimLeft = true;
      }
      _inTag = true;
      tokens.add(
        Token(
          type: TokenType.tagStart,
          lexeme: trimLeft ? '{%-' : '{%',
          location: SourceLocation(
            offset: _start,
            line: _line,
            column: _startColumn,
          ),
          trimLeft: trimLeft,
        ),
      );
    }
  }

  void _scanInsideTag(List<Token> tokens) {
    _skipWhitespaceInsideTag();
    if (_isAtEnd()) return;

    _start = _current;
    _startColumn = _column;

    final c = _advance();

    // Check for variable end
    if (_inVariable) {
      if (c == '-' && _peek() == '}' && _peekNext() == '}') {
        _advance(); // }
        _advance(); // }
        _inVariable = false;
        tokens.add(
          Token(
            type: TokenType.variableEnd,
            lexeme: '-}}',
            location: SourceLocation(
              offset: _start,
              line: _line,
              column: _startColumn,
            ),
            trimRight: true,
          ),
        );
        return;
      } else if (c == '}' && _peek() == '}') {
        _advance(); // }
        _inVariable = false;
        tokens.add(
          Token(
            type: TokenType.variableEnd,
            lexeme: '}}',
            location: SourceLocation(
              offset: _start,
              line: _line,
              column: _startColumn,
            ),
          ),
        );
        return;
      }
    }

    // Check for tag end
    if (_inTag) {
      if (c == '-' && _peek() == '%' && _peekNext() == '}') {
        _advance(); // %
        _advance(); // }
        _inTag = false;
        tokens.add(
          Token(
            type: TokenType.tagEnd,
            lexeme: '-%}',
            location: SourceLocation(
              offset: _start,
              line: _line,
              column: _startColumn,
            ),
            trimRight: true,
          ),
        );
        return;
      } else if (c == '%' && _peek() == '}') {
        _advance(); // }
        _inTag = false;
        tokens.add(
          Token(
            type: TokenType.tagEnd,
            lexeme: '%}',
            location: SourceLocation(
              offset: _start,
              line: _line,
              column: _startColumn,
            ),
          ),
        );
        return;
      }
    }

    switch (c) {
      case '|':
        _addToken(tokens, TokenType.pipe);
        break;
      case ':':
        _addToken(tokens, TokenType.colon);
        break;
      case ',':
        _addToken(tokens, TokenType.comma);
        break;
      case '.':
        _addToken(tokens, TokenType.dot);
        break;
      case '(':
        _addToken(tokens, TokenType.leftParen);
        break;
      case ')':
        _addToken(tokens, TokenType.rightParen);
        break;
      case '[':
        _addToken(tokens, TokenType.leftBracket);
        break;
      case ']':
        _addToken(tokens, TokenType.rightBracket);
        break;
      case '=':
        if (_match('=')) {
          _addToken(tokens, TokenType.operatorEqual);
        } else {
          throw KnapSyntaxException(
            "Unexpected character '=', did you mean '=='?",
            SourceLocation(offset: _start, line: _line, column: _startColumn),
          );
        }
        break;
      case '!':
        if (_match('=')) {
          _addToken(tokens, TokenType.operatorNotEqual);
        } else {
          _addToken(tokens, TokenType.kwNot);
        }
        break;
      case '<':
        _addToken(
          tokens,
          _match('=') ? TokenType.operatorLessEqual : TokenType.operatorLess,
        );
        break;
      case '>':
        _addToken(
          tokens,
          _match('=')
              ? TokenType.operatorGreaterEqual
              : TokenType.operatorGreater,
        );
        break;
      case '"':
      case "'":
        _scanString(tokens, c);
        break;
      default:
        if (_isDigit(c)) {
          _scanNumber(tokens);
        } else if (_isAlpha(c)) {
          _scanIdentifier(tokens);
        } else {
          throw KnapSyntaxException(
            'Unexpected character: $c',
            SourceLocation(offset: _start, line: _line, column: _startColumn),
          );
        }
        break;
    }
  }

  void _scanString(List<Token> tokens, String quoteChar) {
    final buffer = StringBuffer();
    while (!_isAtEnd() && _peek() != quoteChar) {
      if (_peek() == '\\') {
        _advance();
        if (!_isAtEnd()) {
          final escaped = _advance();
          switch (escaped) {
            case 'n':
              buffer.write('\n');
              break;
            case 't':
              buffer.write('\t');
              break;
            case 'r':
              buffer.write('\r');
              break;
            case '\\':
              buffer.write('\\');
              break;
            case '"':
              buffer.write('"');
              break;
            case "'":
              buffer.write("'");
              break;
            default:
              buffer.write(escaped);
          }
        }
      } else {
        buffer.write(_advance());
      }
    }

    if (_isAtEnd()) {
      throw KnapSyntaxException(
        'Unterminated string',
        SourceLocation(offset: _start, line: _line, column: _startColumn),
      );
    }

    _advance(); // Consume closing quote
    final literalValue = buffer.toString();
    tokens.add(
      Token(
        type: TokenType.string,
        lexeme: source.substring(_start, _current),
        literal: literalValue,
        location: SourceLocation(
          offset: _start,
          line: _line,
          column: _startColumn,
        ),
      ),
    );
  }

  void _scanNumber(List<Token> tokens) {
    while (_isDigit(_peek())) {
      _advance();
    }

    var isDouble = false;
    if (_peek() == '.' && _isDigit(_peekNext())) {
      isDouble = true;
      _advance(); // Consume '.'
      while (_isDigit(_peek())) {
        _advance();
      }
    }

    final text = source.substring(_start, _current);
    final num value = isDouble ? double.parse(text) : int.parse(text);

    tokens.add(
      Token(
        type: TokenType.number,
        lexeme: text,
        literal: value,
        location: SourceLocation(
          offset: _start,
          line: _line,
          column: _startColumn,
        ),
      ),
    );
  }

  void _scanIdentifier(List<Token> tokens) {
    while (_isAlphaNumeric(_peek())) {
      _advance();
    }

    final text = source.substring(_start, _current);
    final type = _keywords[text] ?? TokenType.identifier;

    Object? literal;
    if (type == TokenType.boolean) {
      literal = (text == 'true');
    }

    tokens.add(
      Token(
        type: type,
        lexeme: text,
        literal: literal,
        location: SourceLocation(
          offset: _start,
          line: _line,
          column: _startColumn,
        ),
      ),
    );
  }

  void _skipWhitespaceInsideTag() {
    while (!_isAtEnd()) {
      final c = _peek();
      if (c == ' ' || c == '\r' || c == '\t' || c == '\n') {
        _advance();
      } else {
        break;
      }
    }
  }

  List<Token> _applyWhitespaceTrimming(List<Token> tokens) {
    final result = <Token>[];

    for (var i = 0; i < tokens.length; i++) {
      var token = tokens[i];

      // If this token is a start tag with trimLeft, trim preceding text token
      if (token.trimLeft && result.isNotEmpty) {
        final last = result.last;
        if (last.type == TokenType.text) {
          final trimmedText = (last.literal as String).trimRight();
          result[result.length - 1] = Token(
            type: TokenType.text,
            lexeme: trimmedText,
            literal: trimmedText,
            location: last.location,
          );
        }
      }

      // If previous token was an end tag with trimRight, trim this text token if it's text
      if (result.isNotEmpty && result.last.trimRight && token.type == TokenType.text) {
        final trimmedText = (token.literal as String).trimLeft();
        token = Token(
          type: TokenType.text,
          lexeme: trimmedText,
          literal: trimmedText,
          location: token.location,
        );
      }

      result.add(token);
    }

    return result;
  }

  String _advance() {
    final c = source[_current++];
    if (c == '\n') {
      _line++;
      _column = 1;
    } else {
      _column++;
    }
    return c;
  }

  bool _match(String expected) {
    if (_isAtEnd()) return false;
    if (source[_current] != expected) return false;
    _advance();
    return true;
  }

  String _peek() {
    if (_isAtEnd()) return '';
    return source[_current];
  }

  String _peekNext() {
    if (_current + 1 >= source.length) return '';
    return source[_current + 1];
  }

  bool _isAtEnd() => _current >= source.length;

  bool _isDigit(String c) => c.isNotEmpty && c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  bool _isAlpha(String c) {
    if (c.isEmpty) return false;
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122) || // a-z
        code == 95; // _
  }

  bool _isAlphaNumeric(String c) => _isAlpha(c) || _isDigit(c);

  void _addToken(List<Token> tokens, TokenType type) {
    tokens.add(
      Token(
        type: type,
        lexeme: source.substring(_start, _current),
        location: SourceLocation(
          offset: _start,
          line: _line,
          column: _startColumn,
        ),
      ),
    );
  }

  static const Map<String, TokenType> _keywords = {
    'if': TokenType.kwIf,
    'elif': TokenType.kwElif,
    'else': TokenType.kwElse,
    'endif': TokenType.kwEndif,
    'for': TokenType.kwFor,
    'in': TokenType.kwIn,
    'endfor': TokenType.kwEndfor,
    'and': TokenType.kwAnd,
    'or': TokenType.kwOr,
    'not': TokenType.kwNot,
    'true': TokenType.boolean,
    'false': TokenType.boolean,
    'null': TokenType.nullLiteral,
    'nil': TokenType.nullLiteral,
    'none': TokenType.nullLiteral,
  };
}
