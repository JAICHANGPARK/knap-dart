import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('Lexer Edge Cases and Error Handling', () {
    test('scans trim tags with whitespace trimming on tag start {%-', () {
      final engine = KnapEngine.standard();
      expect(engine.render('Prefix   {%- if true %} content {%- endif %}'), 'Prefix content');
    });

    test('throws KnapSyntaxException on invalid single ?', () {
      final lexer = KnapLexer('{{ a ? b }}');
      expect(() => lexer.scanTokens(), throwsA(isA<KnapSyntaxException>()));
    });

    test('throws KnapSyntaxException on unexpected character', () {
      final lexer = KnapLexer('{{ @bad }}');
      expect(() => lexer.scanTokens(), throwsA(isA<KnapSyntaxException>()));
    });

    test('throws KnapSyntaxException on unterminated string', () {
      final lexer = KnapLexer('{{ "unclosed string }}');
      expect(() => lexer.scanTokens(), throwsA(isA<KnapSyntaxException>()));
    });

    test('scans string escape characters correctly', () {
      final engine = KnapEngine.standard();
      expect(
        engine.render(r"""{{ "line1\nline2\ttab\rcarriage\\slash\"quote\'single\xother" }}"""),
        'line1\nline2\ttab\rcarriage\\slash"quote\'singlexother',
      );
    });

    test('scans comparison and boolean tokens', () {
      final engine = KnapEngine.standard();
      expect(engine.render('{{ true }} {{ false }}'), 'true false');
      expect(engine.render('{{ (1 < 2) and (3 <= 3) and (4 > 3) and (5 >= 5) and (1 != 2) and (!false) }}'), 'true');
    });
  });

  group('Parser Error Handling and Edge Cases', () {
    final engine = KnapEngine.standard();

    test('throws on unclosed if tag', () {
      expect(() => engine.render('{% if true %} unclosed'), throwsA(isA<KnapSyntaxException>()));
    });

    test('throws on unclosed for tag', () {
      expect(() => engine.render('{% for x in list %} unclosed'), throwsA(isA<KnapSyntaxException>()));
    });

    test('throws on unexpected tag name', () {
      expect(() => engine.render('{% unknown_tag %}'), throwsA(isA<KnapSyntaxException>()));
    });

    test('throws on missing expression', () {
      expect(() => engine.render('{{ }}'), throwsA(isA<KnapSyntaxException>()));
    });

    test('throws on missing property name after dot', () {
      expect(() => engine.render('{{ obj. }}'), throwsA(isA<KnapSyntaxException>()));
    });

    test('throws on missing closing bracket in index access', () {
      expect(() => engine.render('{{ obj[0 }}'), throwsA(isA<KnapSyntaxException>()));
    });

    test('throws on missing closing parenthesis', () {
      expect(() => engine.render('{{ (1 + 2 }}'), throwsA(isA<KnapSyntaxException>()));
    });

    test('throws on missing closing bracket in list literal', () {
      expect(() => engine.render('{{ [1, 2 }}'), throwsA(isA<KnapSyntaxException>()));
    });

    test('parses complex logical expressions with and, or, not, and grouping', () {
      expect(
        engine.render('{% if (true or false) and not false %}OK{% endif %}'),
        'OK',
      );
      expect(
        engine.render('{% if false or (false and true) %}NO{% else %}YES{% endif %}'),
        'YES',
      );
    });
  });
}
