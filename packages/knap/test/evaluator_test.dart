import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('KnapEvaluator', () {
    final engine = KnapEngine.standard();

    test('renders nested properties and index access', () {
      final template = '{{ user.profile.name }} has {{ user.items[0] }}';
      final output = engine.render(template, data: {
        'user': {
          'profile': {'name': 'Alice'},
          'items': ['Pen', 'Notebook'],
        },
      });
      expect(output, 'Alice has Pen');
    });

    test('evaluates if/elif/else branch logic', () {
      const template = '''
{% if score >= 90 %}
A
{% elif score >= 80 %}
B
{% else %}
C
{% endif %}
''';
      expect(engine.render(template, data: {'score': 95}).trim(), 'A');
      expect(engine.render(template, data: {'score': 85}).trim(), 'B');
      expect(engine.render(template, data: {'score': 70}).trim(), 'C');
    });

    test('evaluates for-loop with loop meta variables', () {
      const template = '{% for item in items %}{{ loop.index }}. {{ item }}{% if not loop.last %}, {% endif %}{% endfor %}';
      final output = engine.render(template, data: {
        'items': ['One', 'Two', 'Three'],
      });
      expect(output, '1. One, 2. Two, 3. Three');
    });

    test('supports renderAsync with async filters', () async {
      final asyncEngine = KnapEngine(
        filters: standardFilters,
        asyncFilters: {
          'fetchMock': (val, args) async {
            await Future.delayed(const Duration(milliseconds: 10));
            return 'Data for $val';
          },
        },
      );

      final result = await asyncEngine.renderAsync(
        '{{ "item1" | fetchMock }}',
      );
      expect(result, 'Data for item1');
    });
  });
}
