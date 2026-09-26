import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('KnapScope and KnapContext', () {
    test('KnapScope lookup in current and parent scopes', () {
      final parent = KnapScope({'a': 1, 'b': 2});
      final child = KnapScope({'b': 20, 'c': 30}, parent);

      expect(child.lookup('a'), 1);
      expect(child.lookup('b'), 20);
      expect(child.lookup('c'), 30);
      expect(child.lookup('d'), isNull);

      child.set('d', 40);
      expect(child.lookup('d'), 40);
    });

    test('KnapContext variable scoping and stack', () {
      final ctx = KnapContext(variables: {'x': 100});
      expect(ctx.resolve('x'), 100);

      ctx.pushScope({'x': 200, 'y': 300});
      expect(ctx.resolve('x'), 200);
      expect(ctx.resolve('y'), 300);

      ctx.popScope();
      expect(ctx.resolve('x'), 100);
      expect(ctx.resolve('y'), isNull);

      // Popping root scope should be safe no-op
      ctx.popScope();
      expect(ctx.resolve('x'), 100);

      ctx.setVariable('z', 999);
      expect(ctx.resolve('z'), 999);
    });

    test('resolveProperty handles various types and keys', () {
      final ctx = KnapContext();

      // Null target
      expect(ctx.resolveProperty(null, 'foo'), isNull);

      // Map target
      final map = {'name': 'Alice', 123: 'numericKey'};
      expect(ctx.resolveProperty(map, 'name'), 'Alice');
      expect(ctx.resolveProperty(map, '123'), 'numericKey');
      expect(ctx.resolveProperty(map, 'length'), 2);
      expect(ctx.resolveProperty(map, 'keys'), contains('name'));
      expect(ctx.resolveProperty(map, 'values'), contains('Alice'));
      expect(ctx.resolveProperty(map, 'nonexistent'), isNull);

      // List target
      final list = ['first_item', 'second_item'];
      expect(ctx.resolveProperty(list, 'length'), 2);
      expect(ctx.resolveProperty(list, 'first'), 'first_item');
      expect(ctx.resolveProperty(list, 'last'), 'second_item');
      expect(ctx.resolveProperty(list, '0'), 'first_item');
      expect(ctx.resolveProperty(list, '1'), 'second_item');
      expect(ctx.resolveProperty(list, '99'), isNull);
      expect(ctx.resolveProperty(list, '-1'), isNull);
      expect(ctx.resolveProperty(list, 'unknown'), isNull);

      // Empty list first/last
      expect(ctx.resolveProperty([], 'first'), isNull);
      expect(ctx.resolveProperty([], 'last'), isNull);

      // String target
      expect(ctx.resolveProperty('hello', 'length'), 5);
      expect(ctx.resolveProperty('hello', 'foo'), isNull);

      // Other primitive types
      expect(ctx.resolveProperty(12345, 'length'), isNull);
    });

    test('resolveIndex handles List, Map, String and numbers', () {
      final ctx = KnapContext();

      // Null target
      expect(ctx.resolveIndex(null, 0), isNull);

      // List target
      final list = ['a', 'b', 'c'];
      expect(ctx.resolveIndex(list, 1), 'b');
      expect(ctx.resolveIndex(list, 1.0), 'b');
      expect(ctx.resolveIndex(list, '2'), 'c');
      expect(ctx.resolveIndex(list, -1), isNull);
      expect(ctx.resolveIndex(list, 10), isNull);
      expect(ctx.resolveIndex(list, 'invalid'), isNull);

      // Map target
      final map = {'key1': 'val1', 42: 'val42'};
      expect(ctx.resolveIndex(map, 'key1'), 'val1');
      expect(ctx.resolveIndex(map, 42), 'val42');
      expect(ctx.resolveIndex(map, '42'), 'val42');
      expect(ctx.resolveIndex(map, 'missing'), isNull);

      // String target
      final str = 'Dart';
      expect(ctx.resolveIndex(str, 0), 'D');
      expect(ctx.resolveIndex(str, '3'), 't');
      expect(ctx.resolveIndex(str, 10), isNull);
      expect(ctx.resolveIndex(str, 'abc'), isNull);

      // Other target
      expect(ctx.resolveIndex(100, 0), isNull);
    });

    test('isTruthy evaluates Knap truthiness rules correctly', () {
      final ctx = KnapContext();

      // Falsey values
      expect(ctx.isTruthy(null), isFalse);
      expect(ctx.isTruthy(false), isFalse);
      expect(ctx.isTruthy(0), isFalse);
      expect(ctx.isTruthy(0.0), isFalse);
      expect(ctx.isTruthy(''), isFalse);
      expect(ctx.isTruthy([]), isFalse);
      expect(ctx.isTruthy({}), isFalse);

      // Truthy values
      expect(ctx.isTruthy(true), isTrue);
      expect(ctx.isTruthy(1), isTrue);
      expect(ctx.isTruthy(-1), isTrue);
      expect(ctx.isTruthy(0.1), isTrue);
      expect(ctx.isTruthy('hello'), isTrue);
      expect(ctx.isTruthy([0]), isTrue);
      expect(ctx.isTruthy({'a': 1}), isTrue);
      expect(ctx.isTruthy(Object()), isTrue);
    });

    test('applyFilter throws KnapEvaluationException on missing filters', () {
      final ctx = KnapContext();
      expect(
        () => ctx.applyFilter('undefined_filter', 'val', []),
        throwsA(isA<KnapEvaluationException>()),
      );
    });

    test('applyFilterAsync throws KnapEvaluationException on missing filters', () async {
      final ctx = KnapContext();
      expect(
        () => ctx.applyFilterAsync('undefined_async_filter', 'val', []),
        throwsA(isA<KnapEvaluationException>()),
      );
    });
  });
}
