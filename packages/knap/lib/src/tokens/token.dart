/// Represents a character position within a template source string.
class SourceLocation {
  /// The 0-based character offset from the start of the source.
  final int offset;

  /// The 1-based line number.
  final int line;

  /// The 1-based column number on the current line.
  final int column;

  /// Creates a source location with character [offset], [line], and [column].
  const SourceLocation({
    required this.offset,
    required this.line,
    required this.column,
  });

  @override
  String toString() => '$line:$column';
}

/// Identifies the lexical category of a template [Token].
enum TokenType {
  /// Raw text content outside of tags.
  text,

  /// Start of a variable interpolation tag (`{{` or `{{-`).
  variableStart,

  /// End of a variable interpolation tag (`}}` or `-}}`).
  variableEnd,

  /// Start of a control flow block tag (`{%` or `{%-`).
  tagStart,

  /// End of a control flow block tag (`%}` or `-%}`).
  tagEnd,

  /// An identifier name for variables, properties, or filters.
  identifier,

  /// A quoted string literal (`"..."` or `'...'`).
  string,

  /// A numeric literal (integer or floating point).
  number,

  /// A boolean literal (`true` or `false`).
  boolean,

  /// A null literal (`null`, `nil`, or `none`).
  nullLiteral,

  /// The filter pipe symbol (`|`).
  pipe,

  /// The colon symbol (`:`) used for filter arguments.
  colon,

  /// The comma separator (`,`).
  comma,

  /// The property access dot (`.`).
  dot,

  /// An opening parenthesis (`(`).
  leftParen,

  /// A closing parenthesis (`)`).
  rightParen,

  /// An opening bracket (`[`).
  leftBracket,

  /// A closing bracket (`]`).
  rightBracket,

  // Operators

  /// Assignment operator (`=`).
  operatorAssign,

  /// Equality operator (`==`).
  operatorEqual,

  /// Inequality operator (`!=`).
  operatorNotEqual,

  /// Less-than operator (`<`).
  operatorLess,

  /// Less-than-or-equal operator (`<=`).
  operatorLessEqual,

  /// Greater-than operator (`>`).
  operatorGreater,

  /// Greater-than-or-equal operator (`>=`).
  operatorGreaterEqual,

  /// Null-coalescing operator (`??`).
  operatorNullCoalescing,

  // Keywords

  /// The `if` keyword.
  kwIf,

  /// The `elif` or `elseif` keyword.
  kwElif,

  /// The `else` keyword.
  kwElse,

  /// The `endif` keyword.
  kwEndif,

  /// The `for` keyword.
  kwFor,

  /// The `in` keyword.
  kwIn,

  /// The `endfor` keyword.
  kwEndfor,

  /// The `set` keyword.
  kwSet,

  /// The logical `and` keyword.
  kwAnd,

  /// The logical `or` keyword.
  kwOr,

  /// The logical `not` keyword.
  kwNot,

  /// The membership `contains` keyword.
  kwContains,

  /// End of input stream marker.
  eof,
}

/// A lexical token scanned from a Knap template string.
class Token {
  /// The category of this token.
  final TokenType type;

  /// The exact substring in the source code representing this token.
  final String lexeme;

  /// The parsed value for literal tokens like numbers, booleans, or strings.
  final Object? literal;

  /// The location in the source text where this token begins.
  final SourceLocation location;

  /// Whether preceding whitespace should be trimmed (`-` modifier).
  final bool trimLeft;

  /// Whether succeeding whitespace should be trimmed (`-` modifier).
  final bool trimRight;

  /// Creates a token with specified [type], [lexeme], [location], and optional metadata.
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
