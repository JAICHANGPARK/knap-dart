import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('100% Coverage Completion Suite', () {
    final engine = KnapEngine.standard();

    test('FilterExpression and AST toString coverage', () {
      final fExpr = FilterExpression(
        const VariableExpression('x'),
        const FilterCall('trim'),
      );
      expect(fExpr.toString(), 'FilterExpr(Var(x) | FilterCall(trim, args: []))');
    });

    test('markdown_filters fragment_link full branches', () {
      final frag = markdownFilters['fragment_link']!;
      // args.length > 1
      expect(
        frag('Target Text', ['CustomLink', 'https://example.com']),
        'Target Text [CustomLink](https://example.com#:~:text=Target%20Text)',
      );
      // words.length > 10
      const longText = 'one two three four five six seven eight nine ten eleven twelve';
      final res = frag(longText, []) as String;
      expect(res, contains('#:~:text=one%20two%20three%20four%20five,eight%20nine%20ten%20eleven%20twelve'));
    });

    test('standard_filters date formatting all token branches', () {
      // MMM, M, GG, W, dddd, ddd, d, H, hh, h, m, s, A, a, literal
      final dt = DateTime(2024, 5, 6, 14, 8, 9);
      final out = engine.render(
        '{{ dateVal | date:"[Date:] MMMM MMM MM M YYYY YY GGGG GG WW W DD D dddd ddd d HH H hh h mm m ss s A a" }}',
        data: {'dateVal': dt},
      );
      expect(out, contains('Date:'));
      expect(out, contains('May'));
      expect(out, contains('2024'));
      expect(out, contains('PM'));
      expect(out, contains('pm'));

      // Custom input format with y
      expect(
        engine.render('{{ "05/06/24" | date:"YYYY-MM-DD":"MM/DD/YY" }}'),
        '2024-05-06',
      );

      // Custom input format mismatch fallback
      expect(
        engine.render('{{ "2024-05-06" | date:"YYYY-MM-DD":"HH:mm:ss" }}'),
        '2024-05-06',
      );
    });

    test('standard_filters slice, split, and string/list filters full branches', () {
      // slice with comma string
      expect(engine.render('{{ "abcdef" | slice:"1, 4" }}'), 'bcd');
      // slice with string single arg
      expect(engine.render('{{ "abcdef" | slice:"2" }}'), 'cdef');
      // slice with string second arg
      expect(engine.render('{{ "abcdef" | slice:(1, "3") }}'), 'bc');
      // slice with negative end on list
      expect(
        engine.render('{{ list | slice:(1, -1) | join }}', data: {'list': ['a', 'b', 'c', 'd']}),
        'b, c',
      );

      // split with /pattern/
      expect(
        engine.render('{{ "a1b2c" | split:"/[0-9]/" | join }}'),
        'a, b, c',
      );

      // strip_tags with Iterable
      expect(
        standardFilters['strip_tags']!('<b><i>test</i></b>', [['b']]),
        '<b>test</b>',
      );

      // remove_html with tag string and Iterable
      expect(
        standardFilters['remove_html']!('<b>hello</b><i>world</i>', ['b']),
        '<i>world</i>',
      );
      expect(
        standardFilters['remove_html']!('<b>hello</b><i>world</i>', [['b']]),
        '<i>world</i>',
      );

      // remove_tags with Iterable
      expect(
        standardFilters['remove_tags']!('<b>hello</b><i>world</i>', [['b']]),
        'hello<i>world</i>',
      );
    });

    test('standard_filters round, number_format, duration full branches', () {
      // round with string decimal arg
      expect(standardFilters['round']!(3.14159, ['2']), 3.14);

      // number_format with string decimal arg
      expect(standardFilters['number_format']!(1234.5678, ['2']), '1,234.57');
      // number_format with numeric string
      expect(standardFilters['number_format']!('1234.5', ['2']), '1,234.50');
      // number_format with Map
      final formattedMap = standardFilters['number_format']!({'val': 1234}, ['2']) as Map;
      expect(formattedMap['val'], '1,234.00');

      // duration with numeric string
      expect(standardFilters['duration']!('3665', []), '01:01:05');
    });

    test('knap_engine diagnostics, limits, and validation full branches', () {
      // renderWithDiagnostics catching KnapLimitException
      final res = engine.renderWithDiagnostics(
        '{% for x in items %}{{ x }}{% endfor %}',
        data: {'items': [1, 2, 3, 4, 5]},
        limits: const RenderLimits(maxOperations: 2),
      );
      expect(res.errors, isNotEmpty);
      expect(res.errors.first.code, TemplateErrorCode.limitExceeded);

      // validateFilters on ListLiteralExpression, UnaryOpExpression, and VariableNode.filters
      final astFilters = engine.compile('{{ [a | non_existent_filter] }} {{ not a }}').ast;
      final filterErrors = engine.validateFilters([
        ...astFilters,
        const VariableNode(
          LiteralExpression('test'),
          filters: [FilterCall('non_existent_filter_2')],
        ),
      ]);
      expect(filterErrors.length, greaterThanOrEqualTo(2));
      expect(filterErrors.any((e) => e.message.contains('non_existent_filter')), isTrue);

      // validateVariables with FilterExpression argument variables
      final astVars = engine.compile('{{ missing_var | trim:arg_var }}').ast;
      final varErrors = engine.validateVariables(astVars, const {});
      expect(varErrors, hasLength(2));
    });

    test('lexer and parser operator and whitespace edge branches', () {
      // lexer slash and star
      final tokens = KnapLexer('{{ a / b * c }}').scanTokens();
      expect(tokens.any((t) => t.type == TokenType.slash), isTrue);
      expect(tokens.any((t) => t.type == TokenType.star), isTrue);

      // lexer CRLF block tag
      final crlfTokens = KnapLexer('{% if true %}\r\nHello{% endif %}').scanTokens();
      expect(crlfTokens.any((t) => t.type == TokenType.text && (t.literal as String).contains('Hello')), isTrue);

      // lexer whitespace before endif with single text token
      final wsTokens = KnapLexer('   {% endif %}').scanTokens();
      expect(wsTokens, isNotEmpty);

      // parser filter delimiter args
      expect(engine.render('{{ "a/b/c" | split:/ | join }}'), 'a, b, c');
      expect(engine.render('{{ "a*b*c" | split:* | join }}'), 'a, b, c');
      expect(engine.render('{{ 10 | calc:+5 }}'), '15');
      expect(engine.compile('{{ items | nth:n+2 }}').ast, isNotEmpty);
      expect(engine.compile('{{ items | nth:n+ }}').ast, isNotEmpty);
      expect(engine.compile('{{ "a" | split:[[0-9]] }}').ast, isNotEmpty);
      expect(engine.compile('{{ items | list:task-1 }}').ast, isNotEmpty);
      expect(engine.compile('{{ items | list:task - 1 }}').ast, isNotEmpty);

      // parser null coalescing in filter arg
      expect(engine.render('{{ "test" | replace:(a ?? "e"):"E" }}'), 'tEst');
    });

    test('evaluator VariableNode with explicit filters sync and async', () async {
      final context = KnapContext(
        filterRegistry: engine.filterRegistry,
      );
      final evaluator = KnapEvaluator(context);
      final node = VariableNode(
        const LiteralExpression('  hello  '),
        filters: const [
          FilterCall('trim'),
          FilterCall('replace', [
            LiteralExpression('hello'),
            LiteralExpression('world'),
          ]),
        ],
      );

      final syncRes = evaluator.evaluate([node]);
      expect(syncRes, 'world');

      final asyncRes = await evaluator.evaluateAsync([node]);
      expect(asyncRes, 'world');
    });
  });
}
