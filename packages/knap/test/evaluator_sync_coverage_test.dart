import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('KnapEvaluator Sync Edge Cases', () {
    late KnapEngine engine;

    setUp(() {
      engine = KnapEngine.standard();
    });

    test('for-loop executes else block when collection is empty or null', () {
      const template = '{% for x in items %}{{ x }}{% else %}NO_ITEMS{% endfor %}';
      expect(engine.render(template, data: {'items': []}), 'NO_ITEMS');
      expect(engine.render(template, data: {'items': null}), 'NO_ITEMS');
    });

    test('for-loop iterates over Set, Map, and single scalar values', () {
      // Iterable (Set)
      expect(
        engine.render('{% for x in items %}{{ x }},{% endfor %}', data: {
          'items': {'a', 'b'},
        }),
        'a,b,',
      );

      // Single scalar value
      expect(
        engine.render('{% for x in item %}{{ x }}{% endfor %}', data: {
          'item': 42,
        }),
        '42',
      );

      // Map entries
      expect(
        engine.render('{% for x in map %}{{ x.key }}:{{ x.value }},{% endfor %}', data: {
          'map': {'k1': 'v1'},
        }),
        'k1:v1,',
      );
    });

    test('evaluates loose equality between numbers and strings', () {
      // num and num
      expect(engine.render('{{ 10 == 10.0 }}'), 'true');
      expect(engine.render('{{ 10 == 20 }}'), 'false');

      // num and string
      expect(engine.render('{{ numVal == strVal }}', data: {'numVal': 42, 'strVal': '42'}), 'true');
      expect(engine.render('{{ numVal == strVal }}', data: {'numVal': 42, 'strVal': 'abc'}), 'false');

      // string and num
      expect(engine.render('{{ strVal == numVal }}', data: {'strVal': '42', 'numVal': 42}), 'true');
      expect(engine.render('{{ strVal == numVal }}', data: {'strVal': 'xyz', 'numVal': 42}), 'false');
    });

    test('evaluates comparison operators for Comparable objects', () {
      final dt1 = DateTime(2026, 1, 1);
      final dt2 = DateTime(2026, 1, 2);

      expect(engine.render('{{ d1 < d2 }}', data: {'d1': dt1, 'd2': dt2}), 'true');
      expect(engine.render('{{ d2 <= d1 }}', data: {'d1': dt1, 'd2': dt2}), 'false');
      expect(engine.render('{{ d2 > d1 }}', data: {'d1': dt1, 'd2': dt2}), 'true');
      expect(engine.render('{{ d1 >= d2 }}', data: {'d1': dt1, 'd2': dt2}), 'false');
    });

    test('evaluates contains operator edge cases', () {
      // null container
      expect(engine.render('{{ nullVal contains "x" }}', data: {'nullVal': null}), 'false');

      // non-container (int)
      expect(engine.render('{{ numVal contains "x" }}', data: {'numVal': 123}), 'false');

      // Map with numeric key matching string
      final mapWithNumKey = {42: 'answer'};
      expect(engine.render('{{ map contains 42 }}', data: {'map': mapWithNumKey}), 'true');
      expect(engine.render('{{ map contains "42" }}', data: {'map': mapWithNumKey}), 'true');
      expect(engine.render('{{ map contains 99 }}', data: {'map': mapWithNumKey}), 'false');
    });
  });
}
