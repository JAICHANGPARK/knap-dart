import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('Token and SourceLocation', () {
    test('SourceLocation.toString returns line:column', () {
      const loc = SourceLocation(offset: 10, line: 2, column: 5);
      expect(loc.toString(), '2:5');
    });

    test('Token.toString returns formatted representation', () {
      const loc = SourceLocation(offset: 0, line: 1, column: 1);
      const token = Token(
        type: TokenType.identifier,
        lexeme: 'myVar',
        location: loc,
      );
      expect(token.toString(), contains('Token(TokenType.identifier, "myVar"'));
    });
  });

  group('AST Nodes toString', () {
    test('all AST nodes implement toString', () {
      const text = TextNode('hello');
      expect(text.toString(), contains('TextNode("hello")'));

      const id = VariableExpression('user');
      expect(id.toString(), 'Var(user)');

      const lit = LiteralExpression(123);
      expect(lit.toString(), 'Literal(123)');

      const prop = PropertyAccessExpression(id, 'name');
      expect(prop.toString(), 'Var(user).name');

      const idx = IndexAccessExpression(id, lit);
      expect(idx.toString(), 'Var(user)[Literal(123)]');

      const unary = UnaryOpExpression(UnaryOperator.not, id);
      expect(unary.toString(), 'UnaryOperator.not(Var(user))');

      const binary = BinaryOpExpression(BinaryOperator.equal, id, lit);
      expect(binary.toString(), 'Binary(Var(user) BinaryOperator.equal Literal(123))');

      const listLit = ListLiteralExpression([lit]);
      expect(listLit.toString(), '[Literal(123)]');

      const filterCall = FilterCall('upper', [lit]);
      expect(filterCall.toString(), contains('FilterCall(upper, args: [Literal(123)])'));

      const varNode = VariableNode(id, filters: [filterCall]);
      expect(varNode.toString(), contains('VariableNode'));

      const setNode = SetNode('x', lit);
      expect(setNode.toString(), 'SetNode(x = Literal(123))');

      const elifBranch = ElifBranch(condition: id, body: [text]);
      expect(elifBranch.body, hasLength(1));

      const ifNode = IfNode(
        condition: id,
        thenBranch: [text],
        elifBranches: [elifBranch],
        elseBranch: [text],
      );
      expect(ifNode.toString(), contains('IfNode'));

      const forNode = ForNode(
        variableName: 'item',
        collection: id,
        body: [text],
        elseBody: [text],
      );
      expect(forNode.toString(), 'ForNode(item in Var(user))');
    });
  });

  group('Exceptions', () {
    test('KnapException subclasses format message and location correctly', () {
      const loc = SourceLocation(offset: 5, line: 1, column: 6);

      const syntaxWithLoc = KnapSyntaxException('Invalid syntax', loc);
      expect(syntaxWithLoc.toString(), 'KnapError at line 1, column 6: Invalid syntax');

      const syntaxNoLoc = KnapSyntaxException('Generic syntax error');
      expect(syntaxNoLoc.toString(), 'KnapError: Generic syntax error');

      const evalWithLoc = KnapEvaluationException('Runtime error', loc);
      expect(evalWithLoc.toString(), 'KnapError at line 1, column 6: Runtime error');

      const evalNoLoc = KnapEvaluationException('Divide by zero');
      expect(evalNoLoc.toString(), 'KnapError: Divide by zero');
    });
  });

  group('FilterRegistry', () {
    test('registers and resolves sync and async filters', () async {
      final registry = FilterRegistry({'init': (v, a) => 'init'});
      expect(registry.has('init'), isTrue);
      expect(registry.getSync('init'), isNotNull);

      registry.register('double', (val, args) => (val as int) * 2);
      registry.registerAsync('triple', (val, args) async => (val as int) * 3);

      expect(registry.getSync('double'), isNotNull);
      expect(registry.getSync('triple'), isNull);
      expect(registry.getAsync('double'), isNotNull);
      expect(registry.getAsync('triple'), isNotNull);

      expect(registry.getSync('double')!(5, []), 10);
      expect(await registry.getAsync('double')!(5, []), 10);
      expect(await registry.getAsync('triple')!(5, []), 15);

      expect(registry.has('double'), isTrue);
      expect(registry.has('triple'), isTrue);
      expect(registry.has('unknown'), isFalse);
      expect(registry.allSync, contains('double'));
    });
  });
}
