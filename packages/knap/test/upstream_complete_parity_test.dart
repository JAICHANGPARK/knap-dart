import 'dart:convert';
import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('Upstream Complete Parity - Newly Added Filters', () {
    final engine = KnapEngine.standard();

    test('embed and wikilink with scalar, list, and map inputs', () {
      expect(engine.render('{{ "Photo.png" | embed }}'), '![[Photo.png]]');
      expect(
        engine.render('{{ "Photo.png" | embed:"Cover" }}'),
        '![[Photo.png|Cover]]',
      );
      expect(markdownFilters['embed']!(null, []), '');
      expect(markdownFilters['embed']!('   ', []), '');
      expect(
        markdownFilters['embed']!({'Page': 'Alias', 'Nested': {'Sub': 'SubAlias'}}, []),
        ['![[Page|Alias]]', '![[Sub|SubAlias]]'],
      );
      expect(
        markdownFilters['embed']!([
          'Img1.png',
          {'Img2.png': 'Second'},
          '',
        ], ['Thumb']),
        ['![[Img1.png|Thumb]]', '![[Img2.png|Second]]'],
      );
      expect(
        markdownFilters['wikilink']!(['Note1', 'Note2'], []),
        ['[[Note1]]', '[[Note2]]'],
      );
    });

    test('table and table_pretty with maps, 2D arrays, 1D arrays, and headers', () {
      final rows = [
        {'Name': 'Alice', 'Role': 'Engineer | Lead'},
        {'Name': 'Bob', 'Role': 'QA'},
      ];
      final pretty = markdownFilters['table_pretty']!(rows, []) as String;
      expect(pretty, contains('| Name  | Role             |'));
      expect(pretty, contains('| ----- | ---------------- |'));
      expect(pretty, contains(r'| Alice | Engineer \| Lead |'));
      expect(pretty, contains('| Bob   | QA               |'));

      // Custom headers as list or multiple args
      final customList = markdownFilters['table_pretty']!(rows, [
        ['Name'],
      ]) as String;
      expect(customList, contains('| Name  |'));

      final customVarargs = markdownFilters['table_pretty']!(
        rows,
        ['Name', 'Role'],
      ) as String;
      expect(customVarargs, contains('| Name  | Role'));

      // Map input to table / table_pretty
      expect(markdownFilters['table_pretty']!({}, []), '');
      final mapTable = markdownFilters['table_pretty']!({
        'Col1': 'Col2',
        'Val1': 'Val2',
      }, []) as String;
      expect(mapTable, contains('| Col1 | Col2 |'));
      expect(mapTable, contains('| Val1 | Val2 |'));

      // 2D list input with and without custom headers
      final matrix = [
        ['A', 'B', 'C'],
        ['1', '2'],
      ];
      final matrixTable = markdownFilters['table_pretty']!(matrix, ['H1', 'H2']) as String;
      expect(matrixTable, contains('| H1  | H2  |     |'));
      final matrixNoHeaders = markdownFilters['table']!(matrix, []) as String;
      expect(matrixNoHeaders, contains('|  |  |  |'));

      // 1D list input with custom headers
      final flatList = ['a', 'b', 'c', 'd'];
      final flatTable = markdownFilters['table']!(flatList, ['C1', 'C2']) as String;
      expect(flatTable, contains('| C1 | C2 |'));
      expect(flatTable, contains('| a | b |'));
      expect(flatTable, contains('| c | d |'));
      expect(
        markdownFilters['table']!(flatList, []),
        '| Value |\n| - |\n| a |\n| b |\n| c |\n| d |',
      );
      expect(markdownFilters['table']!(12345, []), '');
      expect(markdownFilters['table']!(null, []), '');
    });

    test('truncate and truncatewords filters', () {
      final truncate = standardFilters['truncate']!;
      expect(truncate('hello world', [0]), '');
      expect(truncate('hello world', ['5', '!']), 'hell!');

      final truncatewords = standardFilters['truncatewords']!;
      expect(truncatewords('one two three four', []), '');
      expect(truncatewords('one two three four', [0]), '');
      expect(truncatewords('one two', [5]), 'one two');
      expect(truncatewords('one two three four', [2]), 'one two…');
      expect(truncatewords('one   two   three', ['2', '...']), 'one   two...');
    });

    test('yaml and yaml_property filters with block and flow modes', () {
      final yaml = standardFilters['yaml']!;
      expect(yaml([], []), '[]');
      expect(yaml({}, []), '{}');
      expect(yaml(['a', 'b'], []), '- "a"\n- "b"');
      expect(yaml(['a', 'b'], ['flow']), '["a","b"]');
      expect(
        yaml({
          'simple': 'ok',
          'true': 1,
          'nested': ['x'],
          'submap': {'k': 'v'},
        }, []),
        contains('"true": 1'),
      );
      expect(yaml('plain', ['flow']), '"plain"');

      final yamlProp = standardFilters['yaml_property']!;
      expect(yamlProp('Christopher Nolan', []), 'Christopher Nolan');
      expect(yamlProp('Christopher Nolan', ['   ']), 'Christopher Nolan');
      expect(
        yamlProp('Christopher Nolan', ['director']),
        'director: "Christopher Nolan"',
      );
      expect(yamlProp(42, ['count']), 'count: 42');
      expect(yamlProp(true, ['active']), 'active: true');
      expect(yamlProp(null, ['empty']), 'empty: null');
      expect(
        yamlProp(['Sci-Fi', 'Action'], ['genres']),
        'genres:\n  - "Sci-Fi"\n  - "Action"',
      );
    });

    test('stripmd alias and html_to_json / htmlFilters', () {
      expect(
        engine.render('{{ "**Hello** [World](https://x.com)" | stripmd }}'),
        'Hello World',
      );
      expect(htmlFilters['remove_html']!('<b> Bold </b>', []), 'Bold');
      expect(htmlFilters['html_to_json']!('   ', []), '[]');

      final singleJson = htmlFilters['html_to_json']!(
        '<!-- comment --><div class="box" id=\'main\' data-val=123><img src="a.png" /><p>Hello</p>Text</div>',
        [],
      ) as String;
      final decodedSingle = jsonDecode(singleJson) as Map<String, dynamic>;
      expect(decodedSingle['tag'], 'div');
      expect(decodedSingle['attributes']['class'], 'box');
      expect(decodedSingle['attributes']['id'], 'main');
      expect(decodedSingle['attributes']['data-val'], '123');
      expect((decodedSingle['children'] as List).length, 3);

      final multiJson = htmlFilters['html_to_json']!(
        '<p>One</p><p>Two</p>',
        [],
      ) as String;
      final decodedMulti = jsonDecode(multiJson) as List<dynamic>;
      expect(decodedMulti.length, 2);
    });

    test('bold, italic, list, callout, footnote, code enhancements', () {
      expect(engine.render('{{ "word" | bold:_ }}'), '__word__');
      expect(engine.render('{{ "word" | italic:_ }}'), '_word_');
      expect(markdownFilters['bold']!(['a', '', null], ['_']), ['__a__', '', '']);
      expect(markdownFilters['italic']!(['a', '', null], ['_']), ['_a_', '', '']);

      expect(
        engine.render(
          '{{ items | list:numbered }}',
          data: {
            'items': ['First', 'Second'],
          },
        ),
        '1. First\n2. Second',
      );
      expect(
        engine.render(
          '{{ items | list:task }}',
          data: {
            'items': ['Todo 1', 'Todo 2'],
          },
        ),
        '- [ ] Todo 1\n- [ ] Todo 2',
      );
      expect(
        engine.render(
          '{{ items | list:"numbered-task" }}',
          data: {
            'items': [
              'Step 1',
              ['Substep A'],
            ],
          },
        ),
        '1. [ ] Step 1\n\t1. [ ] Substep A',
      );
      expect(markdownFilters['list']!('', []), '');

      // Callout fold states
      expect(
        engine.render('{{ "Body" | callout:("info", "Title", true) }}'),
        '> [!info]- Title\n> Body',
      );
      expect(
        engine.render('{{ "Body" | callout:("info", "", false) }}'),
        '> [!info]+\n> Body',
      );

      // Footnote with List and Map
      expect(
        markdownFilters['footnote']!(['First note', 'Second note'], []),
        '[^1]: First note\n\n[^2]: Second note',
      );
      expect(
        markdownFilters['footnote']!({'firstNote': 'Alpha', 'second_note': 'Beta'}, []),
        '[^first-note]: Alpha\n\n[^second-note]: Beta',
      );
      expect(markdownFilters['footnote']!('   ', []), '');

      // Backtick escaping in inline_code, code, code_block, codeblock
      expect(markdownFilters['inline_code']!('a`b', []), '``a`b``');
      expect(markdownFilters['code']!('a`b', []), '``a`b``');
      expect(markdownFilters['code_block']!('``` inside', []), '````\n``` inside\n````');
      expect(markdownFilters['codeblock']!('``` inside', ['md']), '````md\n``` inside\n````');
    });

    test('safe_name OS modes, map arrow functions, where, sort, replace regex', () {
      final safeName = standardFilters['safe_name']!;
      expect(safeName('con.txt', ['windows']), '_con.txt');
      expect(safeName('.hidden:file/name', ['mac']), '_hiddenfilename');
      expect(safeName('.hidden/linux', ['linux']), '_hiddenlinux');
      expect(safeName('...', ['windows']), 'Untitled');
      expect(safeName('a' * 300, ['linux']).toString().length, 245);

      // map arrow functions & nested paths
      final users = [
        {
          'name': 'Alice',
          'profile': {'age': 30},
          'tags': ['admin'],
        },
        {
          'name': 'Bob',
          'profile': {'age': 25},
          'tags': ['user'],
        },
      ];
      expect(
        engine.render('{{ users | map:u => u.name | join:", " }}', data: {'users': users}),
        'Alice, Bob',
      );
      expect(
        standardFilters['map']!(users, ['u => u.profile.age']),
        [30, 25],
      );
      expect(
        standardFilters['map']!(users, ['u => u.tags[0]']),
        ['admin', 'user'],
      );
      expect(
        standardFilters['map']!(users, ['u => u.tags[99]']),
        [null, null],
      );
      expect(
        standardFilters['map']!(['a', 'b'], ['x => x']),
        ['a', 'b'],
      );
      expect(
        standardFilters['map']!(['a', 'b'], [r'x => "item-${x}"']),
        ['item-a', 'item-b'],
      );
      expect(
        standardFilters['map']!(users, ['u => ({title: u.name, role: "member"})']),
        [
          {'title': 'Alice', 'role': 'member'},
          {'title': 'Bob', 'role': 'member'},
        ],
      );

      // where with nested path
      expect(
        standardFilters['where']!(users, ['profile.age', 25]),
        [users[1]],
      );

      // sort with asc/desc and property
      expect(standardFilters['sort']!([3, 1, 2], ['desc']), [3, 2, 1]);
      expect(
        standardFilters['sort']!(users, ['profile.age', 'asc']),
        [users[1], users[0]],
      );
      expect(
        standardFilters['sort']!(users, ['name', 'desc']),
        [users[1], users[0]],
      );
      expect(
        standardFilters['sort']!([2, 1], ['', 'asc']),
        [1, 2],
      );

      // replace with regex and multi-pairs
      expect(
        standardFilters['replace']!('Hello 123 World 456', [r'/\d+/g', '#']),
        'Hello # World #',
      );
      expect(
        standardFilters['replace']!('foo bar', ['foo', 'baz', 'bar', 'qux']),
        'baz qux',
      );
    });
  });

  group('Lexer, Parser, Limits, Validation & Engine Diagnostics', () {
    test('lexer supports &&, ||, negative numbers, CSS selectors, and unclosed comments', () {
      final engine = KnapEngine.standard();
      expect(
        engine.render('{% if a && b || c %}{{ -42 }}{% endif %}', data: {'a': true, 'b': false, 'c': true}),
        '-42',
      );
      expect(
        engine.render('{{ selector:div.main > p[data-x="1"] }}', data: {
          'selector:div.main > p[data-x="1"]': 'Extracted text',
        }),
        'Extracted text',
      );
      expect(
        engine.render('{{- selectorHtml:article.post -}}', data: {
          'selectorHtml:article.post': '<p>HTML</p>',
        }),
        '<p>HTML</p>',
      );
      expect(
        () => engine.render('{# unclosed comment'),
        throwsA(isA<KnapSyntaxException>()),
      );
      expect(
        () => engine.render('{{ a & b }}'),
        throwsA(isA<KnapSyntaxException>()),
      );
    });

    test('parser supports parenthesized filter args and arrow expressions with strings', () {
      final engine = KnapEngine.standard();
      expect(
        engine.render('{{ items | sort:("age", "desc") | map:x => ({label: "User", name: x.name}) }}', data: {
          'items': [
            {'name': 'A', 'age': 10},
            {'name': 'B', 'age': 20},
          ],
        }),
        '[{"label":"User","name":"B"},{"label":"User","name":"A"}]',
      );
      // Empty parens filter args
      expect(engine.render('{{ " hi " | trim:() }}'), 'hi');
    });

    test('context supports {{wrapped}} keys, variableResolver, asyncVariableResolver, and JSON loop strings', () async {
      final engine = KnapEngine.standard();
      expect(
        engine.render(
          '{{ title }} - {{ user.name }}',
          data: {
            '{{title}}': 'Wrapped Title',
            'user': {'{{name}}': 'Wrapped User'},
          },
        ),
        'Wrapped Title - Wrapped User',
      );

      expect(
        engine.render(
          '{{ dynamic_var }} / {{ unknown | default:fallback_ident }}',
          variableResolver: (name) => name == 'dynamic_var' ? 'Resolved!' : null,
        ),
        'Resolved! / fallback_ident',
      );

      expect(
        await engine.renderAsync(
          '{{ async_var }} / {{ "x" | bold:_ }}',
          asyncVariableResolver: (name) async =>
              name == 'async_var' ? 'AsyncResolved!' : null,
        ),
        'AsyncResolved! / __x__',
      );

      expect(
        await engine.renderAsync(
          '{{ sync_fallback }}',
          variableResolver: (name) => 'SyncFallback!',
        ),
        'SyncFallback!',
      );

      // For loop over JSON array string and item_index
      expect(
        engine.render(
          '{% for tag in jsonTags %}{{ tag_index }}:{{ tag }} {% endfor %}',
          data: {'jsonTags': '["alpha", "beta"]'},
        ),
        '0:alpha \n1:beta',
      );
      expect(
        await engine.renderAsync(
          '{% for tag in jsonTags %}{{ tag_index }}:{{ tag }} {% endfor %}',
          data: {'jsonTags': '["alpha"]'},
        ),
        '0:alpha',
      );

      // Singleton primitive list unwrapping in output
      expect(
        engine.render('{{ items | nth:1 }}', data: {'items': ['only']}),
        'only',
      );

      // Case-insensitive contains on List<String> and String
      expect(
        engine.render(
          '{% if tags contains "DART" and title contains "HELLO" %}yes{% endif %}',
          data: {
            'tags': ['flutter', 'dart'],
            'title': 'Hello World',
          },
        ),
        'yes',
      );
    });

    test('RenderLimits and RenderBudget validation and enforcement', () {
      expect(
        () => const RenderLimits(maxTemplateLength: 0).validate(),
        throwsA(isA<KnapLimitException>()),
      );
      expect(
        () => const RenderLimits(maxOutputLength: 0).validate(),
        throwsA(isA<KnapLimitException>()),
      );
      expect(
        () => const RenderLimits(maxValueLength: 0).validate(),
        throwsA(isA<KnapLimitException>()),
      );
      expect(
        () => const RenderLimits(maxOperations: 0).validate(),
        throwsA(isA<KnapLimitException>()),
      );
      expect(
        () => const RenderLimits(maxDepth: 300).validate(),
        throwsA(isA<KnapLimitException>()),
      );

      final engine = KnapEngine.standard();

      // maxTemplateLength
      expect(
        () => engine.render(
          'hello world',
          limits: const RenderLimits(maxTemplateLength: 5),
        ),
        throwsA(isA<KnapLimitException>()),
      );

      // maxOutputLength
      expect(
        () => engine.render(
          'hello world',
          limits: const RenderLimits(maxOutputLength: 5),
        ),
        throwsA(isA<KnapLimitException>()),
      );

      // maxDepth in parser
      expect(
        () => engine.render(
          '{% if a %}{% if b %}ok{% endif %}{% endif %}',
          limits: const RenderLimits(maxDepth: 1),
        ),
        throwsA(isA<KnapLimitException>()),
      );

      // maxOperations in evaluator
      expect(
        () => engine.render(
          '{% for x in items %}{{ x }}{% endfor %}',
          data: {'items': List.filled(50, 'a')},
          limits: const RenderLimits(maxOperations: 10),
        ),
        throwsA(isA<KnapLimitException>()),
      );

      // RenderBudget checkLength and checkValue limits
      final budget = RenderBudget(
        const RenderLimits(maxValueLength: 10, maxDepth: 2, maxOperations: 50),
      );
      expect(
        () => budget.checkLength(20),
        throwsA(isA<KnapLimitException>()),
      );
      expect(
        () => budget.checkValue('this string is longer than 10 chars'),
        throwsA(isA<KnapLimitException>()),
      );
      expect(
        () => budget.checkValue({
          'a': {
            'b': {'c': 1},
          },
        }),
        throwsA(isA<KnapLimitException>()),
      );

      final smallOpsBudget = RenderBudget(const RenderLimits(maxOperations: 3));
      expect(
        () => smallOpsBudget.checkValue([1, 2, 3, 4, 5]),
        throwsA(isA<KnapLimitException>()),
      );
      final smallMapOpsBudget = RenderBudget(const RenderLimits(maxOperations: 3));
      expect(
        () => smallMapOpsBudget.checkValue({'a': 1, 'b': 2, 'c': 3, 'd': 4}),
        throwsA(isA<KnapLimitException>()),
      );
      final exactEntryLimitBudget = RenderBudget(const RenderLimits(maxOperations: 1));
      expect(
        () => exactEntryLimitBudget.checkValue([1, 2]),
        throwsA(isA<KnapLimitException>()),
      );
    });

    test('validate, validateFilters, validateVariables, renderWithDiagnostics, renderOrThrow, applyFiltersWithRegistry', () {
      final engine = KnapEngine.standard();

      expect(engine.validate('Hello {{ name | upper }}'), isEmpty);

      final syntaxErrors = engine.validate('{% if unclosed %}');
      expect(syntaxErrors, isNotEmpty);
      expect(syntaxErrors.first.code, TemplateErrorCode.parseError);
      expect(syntaxErrors.first.toString(), contains('PARSE_ERROR'));

      final filterErrors = engine.validate('{% if ok %}{{ x | no_such_filter }}{% elif b %}{{ y }}{% else %}{% for i in list %}{{ i }}{% else %}empty{% endfor %}{% set z = 1 %}{% endif %}');
      expect(filterErrors, hasLength(1));
      expect(filterErrors.first.code, TemplateErrorCode.unknownFilter);

      final diagBadFilter = engine.renderWithDiagnostics('{{ x | unknown_f }}');
      expect(diagBadFilter.isSuccess, isFalse);

      final diagSyntaxErr = engine.renderWithDiagnostics('{{ unclosed');
      expect(diagSyntaxErr.isSuccess, isFalse);

      final diagOk = engine.renderWithDiagnostics(
        'Hello {{ name | upper }}',
        data: {'name': 'world'},
      );
      expect(diagOk.isSuccess, isTrue);
      expect(diagOk.output, 'Hello WORLD');

      expect(
        engine.renderOrThrow('{{ name }}', data: {'name': 'Knap'}),
        'Knap',
      );

      // validateVariables across AST nodes
      final compiled = engine.compile(
        'Text {% set localVar = 1 %}'
        '{% if cond and not flag or (arr[idx] == obj.prop) %}'
        '{{ [localVar, missing1] }}'
        '{% elif otherCond %}'
        '{{ missing2 }}'
        '{% else %}'
        '{% for item in items %}{{ item }} {{ item_index }} {{ loop.index }}{% else %}{{ missing3 }}{% endfor %}'
        '{% endif %}',
      );
      final varErrors = engine.validateVariables(compiled.ast, {
        '{{cond}}': true,
        'flag': false,
        'arr': [1],
        'idx': 0,
        'obj': {'prop': 1},
        'otherCond': false,
        'items': [1, 2],
      });
      expect(
        varErrors.map((e) => e.message).toList(),
        containsAll([
          'Undefined variable "missing1"',
          'Undefined variable "missing2"',
          'Undefined variable "missing3"',
        ]),
      );

      // TemplateWarning & Context reportWarning
      final ctx = KnapContext();
      const warning = TemplateWarning(
        message: 'Sample warning',
        filter: 'table',
        code: TemplateWarningCode.invalidFilterInput,
      );
      ctx.reportWarning(warning);
      expect(ctx.warnings, hasLength(1));
      expect(warning.toString(), contains('INVALID_FILTER_INPUT'));

      // applyFiltersWithRegistry
      expect(
        applyFiltersWithRegistry('  hello  ', '', engine.filterRegistry),
        '  hello  ',
      );
      expect(
        applyFiltersWithRegistry(
          '  hello world  ',
          'trim | upper | replace:"WORLD":"DART" | bold:_ | slice:(0, 10)',
          engine.filterRegistry,
        ),
        '__HELLO DA',
      );
      expect(
        applyFiltersWithRegistry(
          'test',
          'replace:(a ?? "t"):"T"',
          engine.filterRegistry,
        ),
        'TesT',
      );

      // Additional branch coverage for strip_md, slice, checkValue maxDepth, and child scope contains
      expect(
        markdownFilters['strip_md']!('![AltText](https://img.com/a.png) [[Target|AliasText]]', []),
        'AltText AliasText',
      );
      expect(standardFilters['slice']!([10, 20, 30], [1]), [20, 30]);
      expect(standardFilters['slice']!('abcdef', [2]), 'cdef');
      expect(
        () => RenderBudget(const RenderLimits(maxDepth: 1)).checkValue({
          'a': {'b': 1},
        }),
        throwsA(isA<KnapLimitException>()),
      );
      expect(
        engine.render(
          '{% for x in items %}{{ null | default:parentFallback }}{% endfor %}',
          data: {
            'items': [1],
            'parentFallback': 'fromParent',
          },
        ),
        'fromParent',
      );
    });

    test('parseCsv handles RFC 4180 CSV with BOM, quotes, escaped quotes, newlines, and errors', () {
      const csv = '\uFEFFtitle,author,notes\r\n'
          '"Hello, World","Alice ""A"" Smith","Line 1\nLine 2"\r\n'
          'Simple,Bob,Note\n\n';
      final rows = parseCsv(csv, source: 'books.csv');
      expect(rows, hasLength(2));
      expect(rows[0]['title'], 'Hello, World');
      expect(rows[0]['author'], 'Alice "A" Smith');
      expect(rows[0]['notes'], 'Line 1\nLine 2');
      expect(rows[1]['title'], 'Simple');

      expect(
        () => parseCsv('a,b\n"unclosed', source: 'bad.csv'),
        throwsA(isA<KnapSyntaxException>()),
      );
      expect(
        () => parseCsv('a,b\n"closed"extra,val', source: 'bad.csv'),
        throwsA(isA<KnapSyntaxException>()),
      );
      expect(
        () => parseCsv('a,b\nun"quoted,val', source: 'bad.csv'),
        throwsA(isA<KnapSyntaxException>()),
      );
      expect(
        () => parseCsv('', source: 'empty.csv'),
        throwsA(isA<KnapSyntaxException>()),
      );
      expect(
        () => parseCsv('a, \n1,2', source: 'blank_header.csv'),
        throwsA(isA<KnapSyntaxException>()),
      );
      expect(
        () => parseCsv('a,a\n1,2', source: 'dup_header.csv'),
        throwsA(isA<KnapSyntaxException>()),
      );
      expect(
        () => parseCsv('a,b\n1', source: 'mismatch.csv'),
        throwsA(isA<KnapSyntaxException>()),
      );
    });
  });
}
