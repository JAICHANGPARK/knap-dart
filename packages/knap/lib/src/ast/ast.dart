sealed class KnapNode {
  const KnapNode();
}

class TextNode extends KnapNode {
  final String text;
  const TextNode(this.text);

  @override
  String toString() => 'TextNode("$text")';
}

class VariableNode extends KnapNode {
  final Expression expression;
  final List<FilterCall> filters;

  const VariableNode(this.expression, {this.filters = const []});

  @override
  String toString() => 'VariableNode($expression, filters: $filters)';
}

class ElifBranch {
  final Expression condition;
  final List<KnapNode> body;

  const ElifBranch({required this.condition, required this.body});
}

class IfNode extends KnapNode {
  final Expression condition;
  final List<KnapNode> thenBranch;
  final List<ElifBranch> elifBranches;
  final List<KnapNode> elseBranch;

  const IfNode({
    required this.condition,
    required this.thenBranch,
    this.elifBranches = const [],
    this.elseBranch = const [],
  });

  @override
  String toString() => 'IfNode($condition, then: ${thenBranch.length} nodes)';
}

class ForNode extends KnapNode {
  final String variableName;
  final Expression collection;
  final List<KnapNode> body;
  final List<KnapNode> elseBody;

  const ForNode({
    required this.variableName,
    required this.collection,
    required this.body,
    this.elseBody = const [],
  });

  @override
  String toString() => 'ForNode($variableName in $collection)';
}

class SetNode extends KnapNode {
  final String name;
  final Expression value;

  const SetNode(this.name, this.value);

  @override
  String toString() => 'SetNode($name = $value)';
}

class FilterCall {
  final String name;
  final List<Expression> arguments;

  const FilterCall(this.name, [this.arguments = const []]);

  @override
  String toString() => 'FilterCall($name, args: $arguments)';
}

// ----------------------------------------------------
// Expressions
// ----------------------------------------------------

sealed class Expression {
  const Expression();
}

class LiteralExpression extends Expression {
  final Object? value;
  const LiteralExpression(this.value);

  @override
  String toString() => 'Literal($value)';
}

class ListLiteralExpression extends Expression {
  final List<Expression> elements;
  const ListLiteralExpression(this.elements);

  @override
  String toString() => '$elements';
}

class VariableExpression extends Expression {
  final String name;
  const VariableExpression(this.name);

  @override
  String toString() => 'Var($name)';
}

class PropertyAccessExpression extends Expression {
  final Expression target;
  final String property;

  const PropertyAccessExpression(this.target, this.property);

  @override
  String toString() => '$target.$property';
}

class IndexAccessExpression extends Expression {
  final Expression target;
  final Expression index;

  const IndexAccessExpression(this.target, this.index);

  @override
  String toString() => '$target[$index]';
}

enum UnaryOperator { not }

class UnaryOpExpression extends Expression {
  final UnaryOperator operator;
  final Expression operand;

  const UnaryOpExpression(this.operator, this.operand);

  @override
  String toString() => '$operator($operand)';
}

enum BinaryOperator {
  and,
  or,
  nullCoalescing,
  contains,
  equal,
  notEqual,
  less,
  lessEqual,
  greater,
  greaterEqual,
}

class BinaryOpExpression extends Expression {
  final BinaryOperator operator;
  final Expression left;
  final Expression right;

  const BinaryOpExpression(this.operator, this.left, this.right);

  @override
  String toString() => 'Binary($left $operator $right)';
}
