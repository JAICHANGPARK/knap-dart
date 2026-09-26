import '../ast/ast.dart';
import '../errors/exceptions.dart';
import '../tokens/token.dart';

class KnapParser {
  final List<Token> tokens;
  int _current = 0;

  KnapParser(this.tokens);

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

    if (_peek().type == TokenType.eof) {
      _advance();
      return null;
    }

    throw KnapSyntaxException('Unexpected token: ${_peek().lexeme}', _peek().location);
  }

  VariableNode _parseVariableNode() {
    final startToken = _previous();
    final expr = _parseExpression();

    final filters = <FilterCall>[];
    while (_match(TokenType.pipe)) {
      final filterToken = _consume(
        TokenType.identifier,
        'Expected filter name after "|"',
      );
      final args = <Expression>[];
      if (_match(TokenType.colon)) {
        args.add(_parseExpression());
        while (_matchAny([TokenType.comma, TokenType.colon])) {
          args.add(_parseExpression());
        }
      }
      filters.add(FilterCall(filterToken.lexeme, args));
    }

    _consume(TokenType.variableEnd, 'Expected "}}" to close variable tag', startToken.location);
    return VariableNode(expr, filters: filters);
  }

  KnapNode _parseTagNode() {
    final tagStartToken = _previous();

    if (_match(TokenType.kwIf)) {
      return _parseIfBlock(tagStartToken);
    }

    if (_match(TokenType.kwFor)) {
      return _parseForBlock(tagStartToken);
    }

    if (_match(TokenType.kwSet)) {
      final nameToken = _consume(TokenType.identifier, 'Expected variable name after "set"');
      _consume(TokenType.operatorAssign, 'Expected "=" after variable name in set tag');
      final valueExpr = _parseExpression();
      _consume(TokenType.tagEnd, 'Expected "%}" to close set tag', tagStartToken.location);
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
    _consume(TokenType.tagEnd, 'Expected "%}" after if condition', startToken.location);

    final thenBranch = _parseBlockUntil([TokenType.kwElif, TokenType.kwElse, TokenType.kwEndif]);
    final elifBranches = <ElifBranch>[];
    final elseBranch = <KnapNode>[];

    while (!_isAtEnd() && _check(TokenType.tagStart) && _peekNext().type == TokenType.kwElif) {
      _advance(); // tagStart
      _advance(); // elif
      final elifCond = _parseExpression();
      _consume(TokenType.tagEnd, 'Expected "%}" after elif condition');
      final elifBody = _parseBlockUntil([TokenType.kwElif, TokenType.kwElse, TokenType.kwEndif]);
      elifBranches.add(ElifBranch(condition: elifCond, body: elifBody));
    }

    if (!_isAtEnd() && _check(TokenType.tagStart) && _peekNext().type == TokenType.kwElse) {
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
    _consume(TokenType.tagEnd, 'Expected "%}" after for expression', startToken.location);

    final body = _parseBlockUntil([TokenType.kwElse, TokenType.kwEndfor]);
    final elseBody = <KnapNode>[];

    if (!_isAtEnd() && _check(TokenType.tagStart) && _peekNext().type == TokenType.kwElse) {
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
    var expr = _parseOr();
    while (_match(TokenType.operatorNullCoalescing)) {
      final right = _parseOr();
      expr = BinaryOpExpression(BinaryOperator.nullCoalescing, expr, right);
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
        TokenType.kwContains => BinaryOperator.contains,
        _ => throw StateError('Unreachable comparison operator: $opType'),
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
      final expr = _parseExpression();
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

  Token _consume(TokenType type, String message, [SourceLocation? fallbackLocation]) {
    if (_check(type)) return _advance();
    throw KnapSyntaxException(message, fallbackLocation ?? _peek().location);
  }
}
