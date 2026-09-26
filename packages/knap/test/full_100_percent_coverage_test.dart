import 'dart:convert';
import 'package:knap/knap.dart';
import 'package:test/test.dart';

class _ThrowingJson {
  Object? toJson() => throw const FormatException('Cannot serialize');
}

void main() {
  group('100% Full Branch Coverage Suite', () {
    final engine = KnapEngine.standard();

    test('markdown table with custom header argument', () {
      final tableFilter = markdownFilters['table']!;
      final data = [
        {'id': 1, 'name': 'Item 1'},
        {'id': 2, 'name': 'Item 2'},
      ];
      final res = tableFilter(data, [
        ['CustomID', 'CustomName']
      ]);
      expect(res, contains('CustomID'));
      expect(res, contains('CustomName'));
    });

    test('parser unexpected token in template flow', () {
      const loc = SourceLocation(offset: 0, line: 1, column: 1);
      final tokens = [
        const Token(type: TokenType.colon, lexeme: ':', location: loc),
        const Token(type: TokenType.eof, lexeme: '', location: loc),
      ];
      final parser = KnapParser(tokens);
      expect(() => parser.parse(), throwsA(isA<KnapSyntaxException>()));
    });

    test('evaluator binary or when left is falsy in async mode', () async {
      final res = await engine.renderAsync('{{ false or "fallbackValue" }}');
      expect(res.trim(), 'fallbackValue');
    });

    test('evaluator comparison fallback for incompatible types', () {
      final dt = DateTime(2026, 1, 1);
      // Incompatible Comparable types throw in compareTo and fallback to string compare
      expect(engine.render('{{ dt < "string" }}', data: {'dt': dt}), 'true');
    });

    test('standard filters missing branch coverage', () {
      // capitalize with non-empty string
      expect(standardFilters['capitalize']!('hello', []), 'Hello');

      // sort on List
      expect(standardFilters['sort']!(['banana', 'apple'], []), ['apple', 'banana']);

      // merge list with non-iterable and map with map
      expect(standardFilters['merge']!([1, 2], [3]), [1, 2, 3]);
      expect(standardFilters['merge']!({'a': 1}, [{'b': 2}]), {'a': 1, 'b': 2});

      // yaml with leading/trailing spaces and special characters
      expect(standardFilters['yaml']!('  leading', []), jsonEncode('  leading'));
      expect(standardFilters['yaml']!('trailing  ', []), jsonEncode('trailing  '));
      expect(standardFilters['yaml']!('key: value', []), jsonEncode('key: value'));

      // json with valid and invalid throwing object
      expect(standardFilters['json']!({'a': 1}, []), contains('"a": 1'));
      expect(standardFilters['json']!(_ThrowingJson(), []), contains('Instance of'));

      // date_modify with units and invalid modifier
      expect(standardFilters['date_modify']!('2026-01-01', ['invalid_mod']), '2026-01-01');
      expect(standardFilters['date_modify']!('2026-01-01', ['+1 month']), contains('2026-02-01'));
      expect(standardFilters['date_modify']!('2026-01-01', ['+1 week']), contains('2026-01-08'));
      expect(standardFilters['date_modify']!('2026-01-01 00:00:00', ['+2 hours', 'YYYY-MM-DD HH:mm:ss']), contains('02:00:00'));
      expect(standardFilters['date_modify']!('2026-01-01 00:00:00', ['+15 minutes', 'YYYY-MM-DD HH:mm:ss']), contains('00:15:00'));
      expect(standardFilters['date_modify']!('2026-01-01 00:00:00', ['+45 seconds', 'YYYY-MM-DD HH:mm:ss']), contains('00:00:45'));

      // indent filter
      expect(standardFilters['indent']!("line1\nline2", [4]), '    line1\n    line2');

      // remove_tags alias
      expect(standardFilters['remove_tags']!('<b>hello</b>', []), 'hello');

      // where filter without expected value (truthy check)
      final items = [
        {'id': 1, 'active': true},
        {'id': 2, 'active': false},
        {'id': 3, 'active': ''},
        {'id': 4, 'active': null},
        {'id': 5, 'active': 'yes'},
      ];
      final activeItems = standardFilters['where']!(items, ['active']) as List;
      expect(activeItems, hasLength(2));

      // sum with string numbers
      expect(standardFilters['sum']!(['10', '25.5'], []), 35.5);

      // number_format with invalid string and without decimals
      expect(standardFilters['number_format']!('invalid_num', []), 'invalid_num');
      expect(standardFilters['number_format']!(1000000, []), '1,000,000');

      // duration with invalid string and under 1 hour
      expect(standardFilters['duration']!('not_number', []), 'not_number');
      expect(standardFilters['duration']!(125, []), '2m 5s');

      // calc with floating point result
      expect(standardFilters['calc']!(10.5, ['+ 0.25']), 10.75);

      // uncamel with consecutive uppercase letters
      expect(standardFilters['uncamel']!('parseJSONDocument', [' ']), 'parse json document');
    });
  });
}
