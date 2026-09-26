/// Base class for all nodes in the Knap abstract syntax tree (AST).
sealed class KnapNode {
  /// Base constant constructor for AST nodes.
  const KnapNode();
}

/// A node representing static literal text outside of tags.
class TextNode extends KnapNode {
  /// The literal text content.
  final String text;

  /// Creates a [TextNode] containing [text].
  const TextNode(this.text);

  @override
  String toString() => 'TextNode("$text")';
}

/// A node representing a variable expression and its filter pipeline (`{{ ... | ... }}`).
class VariableNode extends KnapNode {
  /// The root expression to evaluate.
  final Expression expression;

  /// The ordered sequence of filters to apply to the evaluated expression.
  final List<FilterCall> filters;

  /// Creates a [VariableNode] evaluating [expression] through [filters].
  const VariableNode(this.expression, {this.filters = const []});

  @override
  String toString() => 'VariableNode($expression, filters: $filters)';
}

/// A branch within an [IfNode] corresponding to an `elif` or `elseif` block.
class ElifBranch {
  /// The boolean condition expression guarding this branch.
  final Expression condition;

  /// The list of AST nodes executed if [condition] is truthy.
  final List<KnapNode> body;

  /// Creates an [ElifBranch] with a [condition] and [body].
  const ElifBranch({required this.condition, required this.body});
}

/// A conditional control flow block (`{% if ... %} ... {% endif %}`).
class IfNode extends KnapNode {
  /// The primary condition guarding the [thenBranch].
  final Expression condition;

  /// Nodes evaluated when [condition] is truthy.
  final List<KnapNode> thenBranch;

  /// Optional zero or more `elif` / `elseif` alternate branches.
  final List<ElifBranch> elifBranches;

  /// Optional fallback nodes evaluated when all prior conditions fail.
  final List<KnapNode> elseBranch;

  /// Creates an [IfNode] with [condition], [thenBranch], and optional [elifBranches] and [elseBranch].
  const IfNode({
    required this.condition,
    required this.thenBranch,
    this.elifBranches = const [],
    this.elseBranch = const [],
  });

  @override
  String toString() => 'IfNode($condition, then: ${thenBranch.length} nodes)';
}

/// A loop control flow block (`{% for item in items %} ... {% endfor %}`).
class ForNode extends KnapNode {
  /// The loop variable identifier exposed in the scope for each item.
  final String variableName;

  /// The collection expression to iterate over.
  final Expression collection;

  /// Nodes executed for each element in [collection].
  final List<KnapNode> body;

  /// Optional fallback nodes executed when [collection] is empty or null.
  final List<KnapNode> elseBody;

  /// Creates a [ForNode] iterating [variableName] over [collection].
  const ForNode({
    required this.variableName,
    required this.collection,
    required this.body,
    this.elseBody = const [],
  });

  @override
  String toString() => 'ForNode($variableName in $collection)';
}

/// A variable assignment statement node (`{% set name = expr %}`).
class SetNode extends KnapNode {
  /// The variable name being assigned in the current context.
  final String name;

  /// The expression providing the assigned value.
  final Expression value;

  /// Creates a [SetNode] assigning [name] to [value].
  const SetNode(this.name, this.value);

  @override
  String toString() => 'SetNode($name = $value)';
}

/// A single filter invocation in a filter pipeline.
class FilterCall {
  /// The name of the registered filter to call.
  final String name;

  /// The arguments passed to the filter function.
  final List<Expression> arguments;

  /// Creates a [FilterCall] for [name] with optional [arguments].
  const FilterCall(this.name, [this.arguments = const []]);

  @override
  String toString() => 'FilterCall($name, args: $arguments)';
}

// ----------------------------------------------------
// Expressions
// ----------------------------------------------------

/// Base class for all expressions producing a value in the AST.
sealed class Expression {
  /// Base constant constructor for expressions.
  const Expression();
}

/// A literal value expression (string, number, boolean, or null).
class LiteralExpression extends Expression {
  /// The literal value.
  final Object? value;

  /// Creates a [LiteralExpression] wrapping [value].
  const LiteralExpression(this.value);

  @override
  String toString() => 'Literal($value)';
}

/// A list literal expression (`[elem1, elem2]`).
class ListLiteralExpression extends Expression {
  /// The expressions defining each element in the list.
  final List<Expression> elements;

  /// Creates a [ListLiteralExpression] containing [elements].
  const ListLiteralExpression(this.elements);

  @override
  String toString() => '$elements';
}

/// An expression referencing a variable identifier from the scope.
class VariableExpression extends Expression {
  /// The identifier name of the variable.
  final String name;

  /// Creates a [VariableExpression] resolving [name].
  const VariableExpression(this.name);

  @override
  String toString() => 'Var($name)';
}

/// An expression accessing an object property via dot notation (`target.property`).
class PropertyAccessExpression extends Expression {
  /// The target object expression.
  final Expression target;

  /// The name of the property being accessed.
  final String property;

  /// Creates a [PropertyAccessExpression] for [property] on [target].
  const PropertyAccessExpression(this.target, this.property);

  @override
  String toString() => '$target.$property';
}

/// An expression accessing an element by index or key (`target[index]`).
class IndexAccessExpression extends Expression {
  /// The target collection or map expression.
  final Expression target;

  /// The index or key expression.
  final Expression index;

  /// Creates an [IndexAccessExpression] accessing [index] on [target].
  const IndexAccessExpression(this.target, this.index);

  @override
  String toString() => '$target[$index]';
}

/// The operator for unary expressions.
enum UnaryOperator {
  /// Logical not (`not` or `!`).
  not,
}

/// A unary prefix operator expression.
class UnaryOpExpression extends Expression {
  /// The unary operator.
  final UnaryOperator operator;

  /// The operand expression.
  final Expression operand;

  /// Creates a [UnaryOpExpression] applying [operator] to [operand].
  const UnaryOpExpression(this.operator, this.operand);

  @override
  String toString() => '$operator($operand)';
}

/// Operators supported in binary expressions.
enum BinaryOperator {
  /// Logical AND (`and`).
  and,

  /// Logical OR (`or`).
  or,

  /// Nullish coalescing (`??`).
  nullCoalescing,

  /// Collection or string containment (`contains`).
  contains,

  /// Equality comparison (`==`).
  equal,

  /// Inequality comparison (`!=`).
  notEqual,

  /// Less-than comparison (`<`).
  less,

  /// Less-than-or-equal comparison (`<=`).
  lessEqual,

  /// Greater-than comparison (`>`).
  greater,

  /// Greater-than-or-equal comparison (`>=`).
  greaterEqual,
}

/// An expression evaluating a binary operator between [left] and [right] operands.
class BinaryOpExpression extends Expression {
  /// The binary operator.
  final BinaryOperator operator;

  /// The left-hand operand expression.
  final Expression left;

  /// The right-hand operand expression.
  final Expression right;

  /// Creates a [BinaryOpExpression] applying [operator] to [left] and [right].
  const BinaryOpExpression(this.operator, this.left, this.right);

  @override
  String toString() => 'Binary($left $operator $right)';
}
