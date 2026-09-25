import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('KnapParser', () {
    test('parses variable with filter pipeline', () {
      final lexer = KnapLexer('{{ user.name | trim | upper }}');
      final parser = KnapParser(lexer.scanTokens());
      final nodes = parser.parse();

      expect(nodes.length, 1);
      final varNode = nodes[0] as VariableNode;
      expect(varNode.expression, isA<PropertyAccessExpression>());
      expect(varNode.filters.length, 2);
      expect(varNode.filters[0].name, 'trim');
      expect(varNode.filters[1].name, 'upper');
    });

    test('parses if-elif-else block', () {
      final lexer = KnapLexer('{% if a %}A{% elif b %}B{% else %}C{% endif %}');
      final parser = KnapParser(lexer.scanTokens());
      final nodes = parser.parse();

      expect(nodes.length, 1);
      final ifNode = nodes[0] as IfNode;
      expect(ifNode.thenBranch.length, 1);
      expect(ifNode.elifBranches.length, 1);
      expect(ifNode.elseBranch.length, 1);
    });

    test('parses for-in loop', () {
      final lexer = KnapLexer('{% for item in items %}- {{ item }}\n{% endfor %}');
      final parser = KnapParser(lexer.scanTokens());
      final nodes = parser.parse();

      expect(nodes.length, 1);
      final forNode = nodes[0] as ForNode;
      expect(forNode.variableName, 'item');
      expect(forNode.collection, isA<VariableExpression>());
      expect(forNode.body.length, 3);
    });

    test('throws KnapSyntaxException on unclosed tag', () {
      final lexer = KnapLexer('{% if a %}No closing tag');
      final parser = KnapParser(lexer.scanTokens());
      expect(() => parser.parse(), throwsA(isA<KnapSyntaxException>()));
    });
  });
}
