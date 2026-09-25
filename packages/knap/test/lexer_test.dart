import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('KnapLexer', () {
    test('scans plain text', () {
      final lexer = KnapLexer('Hello world!');
      final tokens = lexer.scanTokens();
      expect(tokens.length, 2);
      expect(tokens[0].type, TokenType.text);
      expect(tokens[0].literal, 'Hello world!');
      expect(tokens[1].type, TokenType.eof);
    });

    test('scans variables', () {
      final lexer = KnapLexer('Hello {{ name }}!');
      final tokens = lexer.scanTokens();
      final types = tokens.map((t) => t.type).toList();
      expect(types, [
        TokenType.text,
        TokenType.variableStart,
        TokenType.identifier,
        TokenType.variableEnd,
        TokenType.text,
        TokenType.eof,
      ]);
    });

    test('scans filters with arguments', () {
      final lexer = KnapLexer('{{ title | truncate: 10, "..." }}');
      final tokens = lexer.scanTokens();
      final types = tokens.map((t) => t.type).toList();
      expect(types, [
        TokenType.variableStart,
        TokenType.identifier,
        TokenType.pipe,
        TokenType.identifier,
        TokenType.colon,
        TokenType.number,
        TokenType.comma,
        TokenType.string,
        TokenType.variableEnd,
        TokenType.eof,
      ]);
    });

    test('handles whitespace trimming flags', () {
      final lexer = KnapLexer('Hello   {{- name -}}   World');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, TokenType.text);
      expect(tokens[0].literal, 'Hello'); // trimmed right!

      expect(tokens[1].type, TokenType.variableStart);
      expect(tokens[1].trimLeft, isTrue);

      expect(tokens[3].type, TokenType.variableEnd);
      expect(tokens[3].trimRight, isTrue);

      expect(tokens[4].type, TokenType.text);
      expect(tokens[4].literal, 'World'); // trimmed left!
    });

    test('scans if and for tags', () {
      final lexer = KnapLexer('{% if count > 0 %}{% for item in items %}{{ item }}{% endfor %}{% endif %}');
      final tokens = lexer.scanTokens();
      final types = tokens.map((t) => t.type).toList();
      expect(types.contains(TokenType.kwIf), isTrue);
      expect(types.contains(TokenType.operatorGreater), isTrue);
      expect(types.contains(TokenType.kwFor), isTrue);
      expect(types.contains(TokenType.kwIn), isTrue);
      expect(types.contains(TokenType.kwEndfor), isTrue);
      expect(types.contains(TokenType.kwEndif), isTrue);
    });
  });
}
