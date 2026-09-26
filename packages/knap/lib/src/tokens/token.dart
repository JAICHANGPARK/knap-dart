class SourceLocation {
  final int offset;
  final int line;
  final int column;

  const SourceLocation({
    required this.offset,
    required this.line,
    required this.column,
  });

  @override
  String toString() => '$line:$column';
}

enum TokenType {
  text,
  variableStart, // {{ or {{-
  variableEnd, // }} or -}}
  tagStart, // {% or {%-
  tagEnd, // %} or -%}

  identifier,
  string,
  number,
  boolean,
  nullLiteral,

  pipe, // |
  colon, // :
  comma, // ,
  dot, // .
  leftParen, // (
  rightParen, // )
  leftBracket, // [
  rightBracket, // ]

  // Operators
  operatorAssign, // =
  operatorEqual, // ==
  operatorNotEqual, // !=
  operatorLess, // <
  operatorLessEqual, // <=
  operatorGreater, // >
  operatorGreaterEqual, // >=
  operatorNullCoalescing, // ??

  // Keywords
  kwIf,
  kwElif,
  kwElse,
  kwEndif,
  kwFor,
  kwIn,
  kwEndfor,
  kwSet,
  kwAnd,
  kwOr,
  kwNot,
  kwContains,

  eof,
}

class Token {
  final TokenType type;
  final String lexeme;
  final Object? literal;
  final SourceLocation location;
  final bool trimLeft;
  final bool trimRight;

  const Token({
    required this.type,
    required this.lexeme,
    this.literal,
    required this.location,
    this.trimLeft = false,
    this.trimRight = false,
  });

  @override
  String toString() => 'Token($type, "$lexeme", loc: $location)';
}
