import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('KnapEngine renderAsync', () {
    late KnapEngine engine;

    setUp(() {
      engine = KnapEngine.standard();
      engine.filterRegistry.registerAsync('async_upper', (val, args) async {
        await Future.delayed(const Duration(milliseconds: 1));
        return val?.toString().toUpperCase();
      });
      engine.filterRegistry.registerAsync('async_add', (val, args) async {
        await Future.delayed(const Duration(milliseconds: 1));
        final n = (val as num?) ?? 0;
        final add = (args.isNotEmpty && args[0] is num) ? args[0] as num : 0;
        return n + add;
      });
    });

    test('evaluates variable interpolation and async filters with arguments', () async {
      final res = await engine.renderAsync(
        'Hello {{ name | async_upper }} {{ count | async_add: 5 }}!',
        data: {'name': 'world', 'count': 10},
      );
      expect(res, 'Hello WORLD 15!');
    });

    test('evaluates if, elif, and else branches asynchronously', () async {
      const template = '''
{% if status == "loading" %}
Loading...
{% elif status == "error" %}
Error occurred!
{% else %}
Success: {{ data }}
{% endif %}
''';

      expect(
        (await engine.renderAsync(template, data: {'status': 'loading'})).trim(),
        'Loading...',
      );
      expect(
        (await engine.renderAsync(template, data: {'status': 'error'})).trim(),
        'Error occurred!',
      );
      expect(
        (await engine.renderAsync(template, data: {'status': 'ok', 'data': 'Done'})).trim(),
        'Success: Done',
      );
    });

    test('evaluates for loops with empty else branch asynchronously', () async {
      const template = '''{% for item in items %}- {{ item }}
{% else %}No items available.{% endfor %}''';

      final withItems = await engine.renderAsync(template, data: {
        'items': ['A', 'B'],
      });
      expect(withItems.trim(), '- A\n- B');

      final emptyItems = await engine.renderAsync(template, data: {
        'items': [],
      });
      expect(emptyItems.trim(), 'No items available.');
    });

    test('evaluates set tags asynchronously', () async {
      const template = '''
{% set greeting = "Hello" %}
{{ greeting }} {{ name }}!
''';
      final res = await engine.renderAsync(template, data: {'name': 'Alice'});
      expect(res.trim(), 'Hello Alice!');
    });

    test('evaluates all binary operators asynchronously', () async {
      // Comparison: <, <=, >, >=, ==, !=
      expect(
        (await engine.renderAsync('{{ a < b }}', data: {'a': 1, 'b': 2})).trim(),
        'true',
      );
      expect(
        (await engine.renderAsync('{{ a <= b }}', data: {'a': 2, 'b': 2})).trim(),
        'true',
      );
      expect(
        (await engine.renderAsync('{{ a > b }}', data: {'a': 3, 'b': 2})).trim(),
        'true',
      );
      expect(
        (await engine.renderAsync('{{ a >= b }}', data: {'a': 3, 'b': 3})).trim(),
        'true',
      );
      expect(
        (await engine.renderAsync('{{ a != b }}', data: {'a': 1, 'b': 2})).trim(),
        'true',
      );
      expect(
        (await engine.renderAsync('{{ a == b }}', data: {'a': 2, 'b': 2})).trim(),
        'true',
      );

      // Logical and, or, not
      expect(
        (await engine.renderAsync('{{ a and b }}', data: {'a': true, 'b': false})).trim(),
        'false',
      );
      expect(
        (await engine.renderAsync('{{ a or b }}', data: {'a': true, 'b': false})).trim(),
        'true',
      );
      expect(
        (await engine.renderAsync('{{ not a }}', data: {'a': false})).trim(),
        'true',
      );

      // Null coalescing ??
      expect(
        (await engine.renderAsync('{{ missing ?? "default" }}', data: {})).trim(),
        'default',
      );

      // Contains operator
      expect(
        (await engine.renderAsync('{{ list contains "x" }}', data: {'list': ['x', 'y']})).trim(),
        'true',
      );
    });

    test('evaluates member access, index access, and list literals asynchronously', () async {
      const template = '''
{{ user.profile.name }} | {{ user['tags'][0] }} | {{ [1, 2, 3][1] }}
''';
      final res = await engine.renderAsync(template, data: {
        'user': {
          'profile': {'name': 'Bob'},
          'tags': ['dart', 'flutter'],
        }
      });
      expect(res.trim(), 'Bob | dart | 2');
    });
  });
}
