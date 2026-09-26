import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('Upstream Parity & Missing Features', () {
    late KnapEngine knap;

    setUp(() {
      knap = KnapEngine.standard();
    });

    test('supports ?? (null coalescing operator)', () {
      final tpl = '{{ title ?? fallback }} - {{ missing ?? "N/A" }}';
      final result = knap.render(tpl, data: {
        'title': null,
        'fallback': 'Default Title',
      });
      expect(result, equals('Default Title - N/A'));
    });

    test('supports contains operator for lists, strings, and maps', () {
      const tpl = '''
{% if tags contains "dart" %}Has Dart!{% endif %}
{% if title contains "Guide" %}Is Guide!{% endif %}
{% if meta contains "author" %}Has Author!{% endif %}
''';
      final result = knap.render(tpl, data: {
        'tags': ['flutter', 'dart', 'knap'],
        'title': 'The Ultimate Guide',
        'meta': {'author': 'Jai', 'year': 2026},
      }).trim();

      expect(result, contains('Has Dart!'));
      expect(result, contains('Is Guide!'));
      expect(result, contains('Has Author!'));
    });

    test('supports elseif keyword as alias for elif', () {
      const tpl = '''
{% if status == "draft" %}Draft
{% elseif status == "review" %}In Review
{% elseif status == "published" %}Published
{% else %}Unknown
{% endif %}''';

      expect(knap.render(tpl, data: {'status': 'draft'}).trim(), equals('Draft'));
      expect(knap.render(tpl, data: {'status': 'review'}).trim(), equals('In Review'));
      expect(knap.render(tpl, data: {'status': 'published'}).trim(), equals('Published'));
      expect(knap.render(tpl, data: {'status': 'archived'}).trim(), equals('Unknown'));
    });

    test('supports multi-word identifiers (e.g. {{ First name }})', () {
      final tpl = 'Hello, {{ First name | upper }}!';
      final result = knap.render(tpl, data: {
        'First name': 'John Doe',
      });
      expect(result, equals('Hello, JOHN DOE!'));
    });

    test('supports colon-chained filter arguments', () {
      final tpl1 = '{{ "hello world" | replace:"world":"dart" }}';
      expect(knap.render(tpl1), equals('hello dart'));

      final tpl2 = '{{ "abcdef" | slice:1:4 }}';
      expect(knap.render(tpl2), equals('bcd'));
    });

    test('safe_name filter sanitizes filename for OS/Obsidian', () {
      final tpl = '{{ "2026/09/26: Meeting? Notes <Draft> | #1" | safe_name }}';
      final result = knap.render(tpl);
      expect(result, equals('20260926 Meeting Notes Draft  1'));

      final tplWithReplacement = '{{ "A/B:C" | safe_name:"-" }}';
      expect(knap.render(tplWithReplacement), equals('A-B-C'));
    });

    test('strip_tags / remove_html / remove_tags filters', () {
      final tpl = '{{ "<p>Hello <b>World</b> &amp; &lt;friends&gt;!</p>" | strip_tags }}';
      expect(knap.render(tpl), equals('Hello World & <friends>!'));

      final tplAlias = '{{ "<div>Test</div>" | remove_html }}';
      expect(knap.render(tplAlias), equals('Test'));
    });

    test('strip_md filter strips markdown formatting', () {
      final md = '# Heading\n\nThis is **bold** and *italic*, with a [link](https://dart.dev) and `code`.';
      final tpl = '{{ content | strip_md }}';
      final result = knap.render(tpl, data: {'content': md});
      expect(result, equals('Heading\n\nThis is bold and italic, with a link and code.'));
    });

    test('collection filters: where, map, compact, split', () {
      final users = [
        {'name': 'Alice', 'role': 'admin'},
        {'name': 'Bob', 'role': 'user'},
        {'name': 'Charlie', 'role': 'admin'},
      ];

      final tplWhereMap = '{{ users | where:"role","admin" | map:"name" | join:", " }}';
      expect(knap.render(tplWhereMap, data: {'users': users}), equals('Alice, Charlie'));

      final tplCompact = '{{ list | compact | join:"-" }}';
      expect(
        knap.render(tplCompact, data: {'list': ['a', '', null, 'b', false, 'c']}),
        equals('a-b-c'),
      );

      final tplSplit = '{{ "apple,banana,orange" | split:"," | first }}';
      expect(knap.render(tplSplit), equals('apple'));
    });

    test('math and formatting filters: sum, round, number_format, duration', () {
      final tplSum = '{{ numbers | sum }}';
      expect(knap.render(tplSum, data: {'numbers': [10, 20.5, 3.5]}), equals('34'));

      final tplRound = '{{ 3.141592 | round:2 }} / {{ 5.8 | round }}';
      expect(knap.render(tplRound), equals('3.14 / 6'));

      final tplNumberFormat = '{{ 1234567.89 | number_format:1 }}';
      expect(knap.render(tplNumberFormat), equals('1,234,567.9'));

      final tplDuration = '{{ 3665 | duration }}';
      expect(knap.render(tplDuration), equals('1h 1m 5s'));
    });

    test('uri and json filters: encode_uri, decode_uri, parse_json', () {
      final tplEncode = '{{ "hello world&dart" | encode_uri }}';
      expect(knap.render(tplEncode), equals('hello%20world%26dart'));

      final tplDecode = '{{ "hello%20world%26dart" | decode_uri }}';
      expect(knap.render(tplDecode), equals('hello world&dart'));

      final tplParseJson = '{{ jsonStr | parse_json | map:"title" | join:", " }}';
      final jsonStr = '[{"title": "Doc 1"}, {"title": "Doc 2"}]';
      expect(knap.render(tplParseJson, data: {'jsonStr': jsonStr}), equals('Doc 1, Doc 2'));
    });

    test('markdown link/footnote/image/blockquote filters', () {
      final tpl = '''
{{ "https://example.com/pic.png" | image:"Logo" }}
{{ "ref1" | footnote }}
{{ "Header Name" | fragment_link }}
{{ "Important text" | blockquote }}
'''.trim();

      final result = knap.render(tpl);
      expect(result, contains('![Logo](https://example.com/pic.png)'));
      expect(result, contains('[^ref1]'));
      expect(result, contains('#header-name'));
      expect(result, contains('> Important text'));
    });

    test('supports calc filter for arithmetic operations', () {
      expect(knap.render('{{ 100 | calc:"+20" }}'), equals('120'));
      expect(knap.render('{{ 100 | calc:"-30" }}'), equals('70'));
      expect(knap.render('{{ 10 | calc:"*5" }}'), equals('50'));
      expect(knap.render('{{ 50 | calc:"/2" }}'), equals('25'));
      expect(knap.render('{{ 2 | calc:"^3" }}'), equals('8'));
    });

    test('supports nth filter (position, multiplier, offset, basis)', () {
      final list = ['a', 'b', 'c', 'd', 'e', 'f'];
      expect(knap.render('{{ list | nth:3 | join }}', data: {'list': list}), equals('c'));
      expect(knap.render('{{ list | nth:"2n" | join:"" }}', data: {'list': list}), equals('bdf'));
      expect(knap.render('{{ list | nth:"n+4" | join:"" }}', data: {'list': list}), equals('def'));
      expect(knap.render('{{ list | nth:"1,3:4" | join:"" }}', data: {'list': list}), equals('ace'));
    });

    test('supports object and template filters', () {
      final map = {'title': 'Knap', 'lang': 'Dart'};
      expect(knap.render('{{ map | object:"keys" | join:"" }}', data: {'map': map}), equals('titlelang'));
      expect(knap.render('{{ map | object:"values" | join:"" }}', data: {'map': map}), equals('KnapDart'));

      final items = [
        {'name': 'Alpha', 'code': 'A'},
        {'name': 'Beta', 'code': 'B'},
      ];
      final res = knap.render('{{ items | template:"\${name}: \${code}" }}', data: {'items': items});
      expect(res, equals('Alpha: A\n\nBeta: B'));
    });

    test('supports uncamel and unescape filters', () {
      expect(knap.render('{{ "fooBarBaz" | uncamel }}'), equals('foo bar baz'));
      expect(knap.render('{{ "\\\"hello\\\\nworld\\\"" | unescape }}'), equals('"hello\nworld"'));
    });

    test('supports HTML attribute filters: strip_attr, remove_attr, replace_tags', () {
      const html = '<div class="box" id="main" style="color:red">Content</div>';
      expect(knap.render('{{ html | strip_attr:"id" }}', data: {'html': html}), equals('<div id="main">Content</div>'));
      expect(knap.render('{{ html | remove_attr:"style" }}', data: {'html': html}), equals('<div class="box" id="main">Content</div>'));
      expect(knap.render('{{ html | replace_tags:"div":"section" }}', data: {'html': html}), equals('<section class="box" id="main" style="color:red">Content</section>'));
    });

    test('supports markdown headings, highlight, math, hr, comment', () {
      expect(knap.render('{{ "Title" | h1 }}'), equals('# Title'));
      expect(knap.render('{{ "Sub" | h2 }}'), equals('## Sub'));
      expect(knap.render('{{ "Notice" | highlight }}'), equals('==Notice=='));
      expect(knap.render('{{ "Warning" | highlight:"red" }}'), equals('==🔴Warning=='));
      expect(knap.render('{{ "E=mc^2" | math }}'), equals(r'$E=mc^2$'));
      expect(knap.render('{{ "Hidden note" | comment }}'), equals('%%Hidden note%%'));
      expect(knap.render('{{ "Above" | hr }}'), equals('Above\n\n---'));
    });
  });
}
