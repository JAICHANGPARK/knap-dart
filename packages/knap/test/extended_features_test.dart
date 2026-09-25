import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('Extended Knap Features', () {
    final engine = KnapEngine.standard();

    test('ignores comments {# ... #} and trims with {#- ... -#}', () {
      final res = engine.render('Hello {# this is hidden #}World');
      expect(res, 'Hello World');

      final resTrim = engine.render('Hello   {#- comment -#}   World');
      expect(resTrim, 'HelloWorld');
    });

    test('supports set tag {% set name = expr %}', () {
      const template = '''
{% set greeting = "Hi" %}
{% set total = 10 %}
{{ greeting }}! Total: {{ total }}
''';
      final res = engine.render(template).trim();
      expect(res, 'Hi! Total: 10');
    });

    test('supports date and date_modify filters', () {
      final res = engine.render(
        '{{ "2026-09-25T10:00:00Z" | date: "YYYY/MM/DD" }}',
      );
      expect(res, '2026/09/25');

      final modified = engine.render(
        '{{ "2026-09-25" | date_modify: "+2 days" }}',
      );
      expect(modified, '2026-09-27');

      final modifiedYear = engine.render(
        '{{ "2026-09-25" | date_modify: "-1 year" }}',
      );
      expect(modifiedYear, '2025-09-25');
    });

    test('supports case filters (snake, camel, kebab, pascal)', () {
      expect(engine.render('{{ text | snake }}', data: {'text': 'hello world'}), 'hello_world');
      expect(engine.render('{{ text | camel }}', data: {'text': 'hello world'}), 'helloWorld');
      expect(engine.render('{{ text | kebab }}', data: {'text': 'Hello World'}), 'hello-world');
      expect(engine.render('{{ text | pascal }}', data: {'text': 'hello world'}), 'HelloWorld');
    });

    test('supports merge, unique, yaml, hard_break filters', () {
      final uniqueRes = engine.render('{{ list | unique | join }}', data: {
        'list': ['a', 'b', 'a', 'c'],
      });
      expect(uniqueRes, 'a, b, c');

      final mergeRes = engine.render('{{ list | merge: ["c", "d"] | join }}', data: {
        'list': ['a', 'b'],
      });
      expect(mergeRes, 'a, b, c, d');

      final yamlRes = engine.render('{{ text | yaml }}', data: {
        'text': 'Note: with colon',
      });
      expect(yamlRes, '"Note: with colon"');

      final hardBreakRes = engine.render('{{ text | hard_break }}', data: {
        'text': 'Line 1\nLine 2',
      });
      expect(hardBreakRes, 'Line 1  \nLine 2');
    });

    test('supports loop.revindex and loop.revindex0', () {
      const template = '{% for x in items %}{{ loop.revindex }}:{{ loop.revindex0 }}{% if not loop.last %},{% endif %}{% endfor %}';
      final res = engine.render(template, data: {
        'items': ['a', 'b', 'c'],
      });
      expect(res, '3:2,2:1,1:0');
    });
  });
}
