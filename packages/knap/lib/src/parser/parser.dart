import '../ast/ast.dart';
import '../errors/exceptions.dart';
import '../limits/render_limits.dart';
import '../tokens/token.dart';

/// A recursive descent parser that converts a stream of [Token]s into an abstract syntax tree of [KnapNode]s.
///
/// ```dart
/// final tokens = KnapLexer('{% if ok %}Yes{% endif %}').scanTokens();
/// final ast = KnapParser(tokens).parse();
/// ```
class KnapParser {
  /// The scanned token stream to parse.
  final List<Token> tokens;

  /// Resource and depth limits enforced during parsing.
  final RenderLimits limits;

  int _current = 0;
  int _depth = 0;

  /// Creates a [KnapParser] over [tokens] with optional [limits].
  KnapParser(this.tokens, {this.limits = defaultRenderLimits}) {
    limits.validate();
  }

  /// Parses the entire token stream and returns the root list of AST [KnapNode]s.
  List<KnapNode> parse() {
    final nodes = <KnapNode>[];
    while (!_isAtEnd()) {
      final node = _parseTopLevelNode();
      if (node != null) {
        nodes.add(node);
      }
    }
    return nodes;
  }

  T _withDepth<T>(SourceLocation location, T Function() action) {
    if (++_depth > limits.maxDepth) {
      throw KnapLimitException('Template exceeded maxDepth', location);
    }
    try {
      return action();
    } finally {
      _depth--;
    }
  }

  KnapNode? _parseTopLevelNode() {
    if (_match(TokenType.text)) {
      return TextNode(_previous().literal as String);
    }

    if (_match(TokenType.variableStart)) {
      return _parseVariableNode();
    }

    if (_match(TokenType.tagStart)) {
      return _parseTagNode();
    }

    throw KnapSyntaxException(
      'Unexpected token: ${_peek().lexeme}',
      _peek().location,
    );
  }

  VariableNode _parseVariableNode() {
    final startToken = _previous();
    final expr = _parseExpression();

    _consume(
      TokenType.variableEnd,
      'Expected "}}" to close variable tag',
      startToken.location,
    );
    return VariableNode(expr);
  }

  void _parseFilterArguments(List<Expression> args) {
    // Support parenthesized argument lists: | filter:("a", "b")
    if (_check(TokenType.leftParen)) {
      _advance(); // consume '('
      if (!_check(TokenType.rightParen)) {
        args.add(_parseSingleFilterArg());
        while (_matchAny([TokenType.comma, TokenType.colon])) {
          args.add(_parseSingleFilterArg());
        }
      }
      _consume(TokenType.rightParen, 'Expected ")" after filter arguments');
      while (_matchAny([TokenType.comma, TokenType.colon])) {
        args.add(_parseSingleFilterArg());
      }
      return;
    }

    args.add(_parseSingleFilterArg());
    while (_matchAny([TokenType.comma, TokenType.colon])) {
      args.add(_parseSingleFilterArg());
    }
  }

  Expression _parseSingleFilterArg() {
    // Check for delimiter symbols as args (e.g. split:/, split:*, split:-, calc:+1)
    if (_check(TokenType.slash) ||
        _check(TokenType.star) ||
        _check(TokenType.minus) ||
        _check(TokenType.plus)) {
      final token = _advance();
      if (_check(TokenType.number)) {
        final numToken = _advance();
        return LiteralExpression('${token.lexeme}${numToken.lexeme}');
      }
      return LiteralExpression(token.lexeme);
    }

    // Check for bracket regex pattern: e.g. [0-9]
    if (_check(TokenType.leftBracket)) {
      var isRegexClass = false;
      var i = 1;
      while (_current + i < tokens.length) {
        final t = tokens[_current + i];
        if (t.type == TokenType.rightBracket) break;
        if (t.type == TokenType.comma || t.type == TokenType.string) {
          isRegexClass = false;
          break;
        }
        if (t.type == TokenType.minus || t.lexeme.contains('-') || t.lexeme == '^') {
          isRegexClass = true;
        }
        i++;
      }
      if (isRegexClass) {
        _advance(); // consume '['
        final buffer = StringBuffer('[');
        var depth = 1;
        while (!_isAtEnd() && depth > 0) {
          final token = _peek();
          if (token.type == TokenType.leftBracket) {
            depth++;
          } else if (token.type == TokenType.rightBracket) {
            depth--;
            buffer.write(']');
            _advance();
            if (depth == 0) break;
            continue;
          }
          buffer.write(token.lexeme);
          _advance();
        }
        return LiteralExpression(buffer.toString());
      }
    }

    // Check for number + identifier: e.g. 2n
    if (_check(TokenType.number) && _peekNext().type == TokenType.identifier) {
      final numToken = _advance();
      final idToken = _advance();
      return LiteralExpression('${numToken.lexeme}${idToken.lexeme}');
    }

    // Check for identifier + plus + number: e.g. n+7
    if (_check(TokenType.identifier) && _peekNext().type == TokenType.plus) {
      final idToken = _advance();
      _advance(); // plus
      if (_check(TokenType.number)) {
        final numToken = _advance();
        return LiteralExpression('${idToken.lexeme}+${numToken.lexeme}');
      }
      return LiteralExpression('${idToken.lexeme}+');
    }

    // Check for arrow expression: identifier => ...
    if (_check(TokenType.identifier) && _peekNext().type == TokenType.arrow) {
      final idToken = _advance();
      _advance(); // consume '=>'
      final buffer = StringBuffer('${idToken.lexeme} => ');
      var braceDepth = 0;
      var parenDepth = 0;

      while (!_isAtEnd()) {
        final token = _peek();
        if (braceDepth == 0 && parenDepth == 0) {
          if (token.type == TokenType.pipe ||
              token.type == TokenType.variableEnd ||
              token.type == TokenType.tagEnd) {
            break;
          }
        }
        if (token.type == TokenType.leftBrace) {
          braceDepth++;
        } else if (token.type == TokenType.leftParen) {
          parenDepth++;
        } else if (token.type == TokenType.rightBrace) {
          braceDepth--;
          if (braceDepth < 0) break;
        } else if (token.type == TokenType.rightParen) {
          parenDepth--;
          if (parenDepth < 0) break;
        }

        if (token.type == TokenType.string) {
          buffer.write('"${token.literal}"');
        } else {
          buffer.write(token.lexeme);
        }
        _advance();
      }
      return LiteralExpression(buffer.toString().trim());
    }

    // Check for hyphenated identifier: e.g. numbered-task, pt-BR, task-1
    if (_check(TokenType.identifier)) {
      if (_peekNext().type == TokenType.minus) {
        final buffer = StringBuffer(_advance().lexeme);
        while (_check(TokenType.minus) &&
            (_peekNext().type == TokenType.identifier ||
                _peekNext().type == TokenType.number)) {
          buffer.write(_advance().lexeme); // minus
          buffer.write(_advance().lexeme); // identifier / number
        }
        return LiteralExpression(buffer.toString());
      } else if (_peekNext().type == TokenType.number &&
          _peekNext().lexeme.startsWith('-')) {
        final id = _advance().lexeme;
        final numLex = _advance().lexeme;
        return LiteralExpression('$id$numLex');
      }
    }

    return _parseNullCoalescingWithoutFilter();
  }

  Expression _parseNullCoalescingWithoutFilter() {
    var expr = _parseOr();
    while (_match(TokenType.operatorNullCoalescing)) {
      final right = _parseOr();
      expr = BinaryOpExpression(BinaryOperator.nullCoalescing, expr, right);
    }
    return expr;
  }

  KnapNode _parseTagNode() {
    final tagStartToken = _previous();

    if (_match(TokenType.kwIf)) {
      return _withDepth(
        tagStartToken.location,
        () => _parseIfBlock(tagStartToken),
      );
    }

    if (_match(TokenType.kwFor)) {
      return _withDepth(
        tagStartToken.location,
        () => _parseForBlock(tagStartToken),
      );
    }

    if (_match(TokenType.kwSet)) {
      final nameToken = _consume(
        TokenType.identifier,
        'Expected variable name after "set"',
      );
      _consume(
        TokenType.operatorAssign,
        'Expected "=" after variable name in set tag',
      );
      final valueExpr = _parseExpression();
      _consume(
        TokenType.tagEnd,
        'Expected "%}" to close set tag',
        tagStartToken.location,
      );
      return SetNode(nameToken.lexeme, valueExpr);
    }

    // Invalid tag inside general template flow
    final invalidTag = _peek();
    throw KnapSyntaxException(
      'Unexpected tag "${invalidTag.lexeme}"',
      invalidTag.location,
    );
  }

  IfNode _parseIfBlock(Token startToken) {
    final condition = _parseExpression();
    _consume(
      TokenType.tagEnd,
      'Expected "%}" after if condition',
      startToken.location,
    );

    final thenBranch = _parseBlockUntil([
      TokenType.kwElif,
      TokenType.kwElse,
      TokenType.kwEndif,
    ]);
    final elifBranches = <ElifBranch>[];
    final elseBranch = <KnapNode>[];

    while (!_isAtEnd() &&
        _check(TokenType.tagStart) &&
        _peekNext().type == TokenType.kwElif) {
      _advance(); // tagStart
      _advance(); // elif
      final elifCond = _parseExpression();
      _consume(TokenType.tagEnd, 'Expected "%}" after elif condition');
      final elifBody = _parseBlockUntil([
        TokenType.kwElif,
        TokenType.kwElse,
        TokenType.kwEndif,
      ]);
      elifBranches.add(ElifBranch(condition: elifCond, body: elifBody));
    }

    if (!_isAtEnd() &&
        _check(TokenType.tagStart) &&
        _peekNext().type == TokenType.kwElse) {
      _advance(); // tagStart
      _advance(); // else
      _consume(TokenType.tagEnd, 'Expected "%}" after else');
      elseBranch.addAll(_parseBlockUntil([TokenType.kwEndif]));
    }

    if (_check(TokenType.tagStart) && _peekNext().type == TokenType.kwEndif) {
      _advance(); // tagStart
      _advance(); // endif
      _consume(TokenType.tagEnd, 'Expected "%}" after endif');
      return IfNode(
        condition: condition,
        thenBranch: thenBranch,
        elifBranches: elifBranches,
        elseBranch: elseBranch,
      );
    }

    throw KnapSyntaxException('Unclosed {% if %} tag', startToken.location);
  }

  ForNode _parseForBlock(Token startToken) {
    final varToken = _consume(
      TokenType.identifier,
      'Expected variable name in for loop',
    );
    _consume(TokenType.kwIn, 'Expected "in" after variable name in for loop');
    final collection = _parseExpression();
    _consume(
      TokenType.tagEnd,
      'Expected "%}" after for expression',
      startToken.location,
    );

    final body = _parseBlockUntil([TokenType.kwElse, TokenType.kwEndfor]);
    final elseBody = <KnapNode>[];

    if (!_isAtEnd() &&
        _check(TokenType.tagStart) &&
        _peekNext().type == TokenType.kwElse) {
      _advance(); // tagStart
      _advance(); // else
      _consume(TokenType.tagEnd, 'Expected "%}" after else');
      elseBody.addAll(_parseBlockUntil([TokenType.kwEndfor]));
    }

    if (_check(TokenType.tagStart) && _peekNext().type == TokenType.kwEndfor) {
      _advance(); // tagStart
      _advance(); // endfor
      _consume(TokenType.tagEnd, 'Expected "%}" after endfor');
      return ForNode(
        variableName: varToken.lexeme,
        collection: collection,
        body: body,
        elseBody: elseBody,
      );
    }

    throw KnapSyntaxException('Unclosed {% for %} tag', startToken.location);
  }

  List<KnapNode> _parseBlockUntil(List<TokenType> closingTags) {
    final nodes = <KnapNode>[];
    while (!_isAtEnd()) {
      if (_check(TokenType.tagStart)) {
        final nextToken = _peekNext();
        if (closingTags.contains(nextToken.type)) {
          return nodes;
        }
      }
      final node = _parseTopLevelNode();
      if (node != null) {
        nodes.add(node);
      }
    }
    return nodes;
  }

  // ----------------------------------------------------
  // Expression Parsing (Precedence)
  // ----------------------------------------------------

  Expression _parseExpression() => _parseNullCoalescing();

  Expression _parseNullCoalescing() {
    var expr = _parseFilter();
    while (_match(TokenType.operatorNullCoalescing)) {
      final right = _parseFilter();
      expr = BinaryOpExpression(BinaryOperator.nullCoalescing, expr, right);
    }
    return expr;
  }

  Expression _parseFilter() {
    var expr = _parseOr();
    while (_match(TokenType.pipe)) {
      final filterToken = _consume(
        TokenType.identifier,
        'Expected filter name after "|"',
      );
      final args = <Expression>[];
      if (_match(TokenType.colon)) {
        _parseFilterArguments(args);
      }
      expr = FilterExpression(expr, FilterCall(filterToken.lexeme, args));
    }
    return expr;
  }

  Expression _parseOr() {
    var expr = _parseAnd();
    while (_match(TokenType.kwOr)) {
      final right = _parseAnd();
      expr = BinaryOpExpression(BinaryOperator.or, expr, right);
    }
    return expr;
  }

  Expression _parseAnd() {
    var expr = _parseEquality();
    while (_match(TokenType.kwAnd)) {
      final right = _parseEquality();
      expr = BinaryOpExpression(BinaryOperator.and, expr, right);
    }
    return expr;
  }

  Expression _parseEquality() {
    var expr = _parseComparison();
    while (_matchAny([TokenType.operatorEqual, TokenType.operatorNotEqual])) {
      final op = _previous().type == TokenType.operatorEqual
          ? BinaryOperator.equal
          : BinaryOperator.notEqual;
      final right = _parseComparison();
      expr = BinaryOpExpression(op, expr, right);
    }
    return expr;
  }

  Expression _parseComparison() {
    var expr = _parseUnary();
    while (_matchAny([
      TokenType.operatorLess,
      TokenType.operatorLessEqual,
      TokenType.operatorGreater,
      TokenType.operatorGreaterEqual,
      TokenType.kwContains,
    ])) {
      final opType = _previous().type;
      final op = switch (opType) {
        TokenType.operatorLess => BinaryOperator.less,
        TokenType.operatorLessEqual => BinaryOperator.lessEqual,
        TokenType.operatorGreater => BinaryOperator.greater,
        TokenType.operatorGreaterEqual => BinaryOperator.greaterEqual,
        _ => BinaryOperator.contains,
      };
      final right = _parseUnary();
      expr = BinaryOpExpression(op, expr, right);
    }
    return expr;
  }

  Expression _parseUnary() {
    if (_matchAny([TokenType.kwNot])) {
      final operand = _parseUnary();
      return UnaryOpExpression(UnaryOperator.not, operand);
    }
    return _parsePostfix();
  }

  Expression _parsePostfix() {
    var expr = _parsePrimary();

    while (true) {
      if (_match(TokenType.dot)) {
        final nameToken = _consume(
          TokenType.identifier,
          'Expected property name after "."',
        );
        expr = PropertyAccessExpression(expr, nameToken.lexeme);
      } else if (_match(TokenType.leftBracket)) {
        final index = _parseExpression();
        _consume(TokenType.rightBracket, 'Expected "]" after index expression');
        expr = IndexAccessExpression(expr, index);
      } else {
        break;
      }
    }

    return expr;
  }

  Expression _parsePrimary() {
    if (_match(TokenType.boolean)) {
      return LiteralExpression(_previous().literal);
    }
    if (_match(TokenType.nullLiteral)) {
      return const LiteralExpression(null);
    }
    if (_match(TokenType.number)) {
      return LiteralExpression(_previous().literal);
    }
    if (_match(TokenType.string)) {
      return LiteralExpression(_previous().literal);
    }
    if (_match(TokenType.identifier)) {
      var name = _previous().lexeme;
      while (_check(TokenType.identifier)) {
        name += ' ${_advance().lexeme}';
      }
      return VariableExpression(name);
    }
    if (_match(TokenType.leftParen)) {
      final loc = _previous().location;
      final expr = _withDepth(loc, _parseExpression);
      _consume(TokenType.rightParen, 'Expected ")" after expression');
      return expr;
    }
    if (_match(TokenType.leftBracket)) {
      final elements = <Expression>[];
      if (!_check(TokenType.rightBracket)) {
        elements.add(_parseExpression());
        while (_match(TokenType.comma)) {
          if (_check(TokenType.rightBracket)) break;
          elements.add(_parseExpression());
        }
      }
      _consume(TokenType.rightBracket, 'Expected "]" after list elements');
      return ListLiteralExpression(elements);
    }

    throw KnapSyntaxException('Expected expression', _peek().location);
  }

  // Helper utilities
  bool _match(TokenType type) {
    if (_check(type)) {
      _advance();
      return true;
    }
    return false;
  }

  bool _matchAny(List<TokenType> types) {
    for (final type in types) {
      if (_check(type)) {
        _advance();
        return true;
      }
    }
    return false;
  }

  bool _check(TokenType type) {
    if (_isAtEnd()) return false;
    return _peek().type == type;
  }

  Token _advance() {
    if (!_isAtEnd()) _current++;
    return _previous();
  }

  bool _isAtEnd() => _peek().type == TokenType.eof;

  Token _peek() => tokens[_current];

  Token _peekNext() {
    if (_current + 1 >= tokens.length) return tokens.last;
    return tokens[_current + 1];
  }

  Token _previous() => tokens[_current - 1];

  Token _consume(
    TokenType type,
    String message, [
    SourceLocation? fallbackLocation,
  ]) {
    if (_check(type)) return _advance();
    throw KnapSyntaxException(message, fallbackLocation ?? _peek().location);
  }
}
