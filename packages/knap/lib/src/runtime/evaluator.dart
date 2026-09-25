import '../ast/ast.dart';
import 'context.dart';

class KnapEvaluator {
  final KnapContext context;

  KnapEvaluator(this.context);

  // ----------------------------------------------------------------------
  // Synchronous Evaluation
  // ----------------------------------------------------------------------

  String evaluate(List<KnapNode> nodes) {
    final buffer = StringBuffer();
    for (final node in nodes) {
      _evaluateNode(node, buffer);
    }
    return buffer.toString();
  }

  void _evaluateNode(KnapNode node, StringBuffer buffer) {
    switch (node) {
      case TextNode(:final text):
        buffer.write(text);

      case VariableNode(:final expression, :final filters):
        var value = _evaluateExpression(expression);
        for (final filter in filters) {
          final filterArgs = filter.arguments.map(_evaluateExpression).toList();
          value = context.applyFilter(filter.name, value, filterArgs);
        }
        if (value != null) {
          buffer.write(value.toString());
        }

      case IfNode(:final condition, :final thenBranch, :final elifBranches, :final elseBranch):
        if (context.isTruthy(_evaluateExpression(condition))) {
          buffer.write(evaluate(thenBranch));
          return;
        }
        for (final elif in elifBranches) {
          if (context.isTruthy(_evaluateExpression(elif.condition))) {
            buffer.write(evaluate(elif.body));
            return;
          }
        }
        if (elseBranch.isNotEmpty) {
          buffer.write(evaluate(elseBranch));
        }

      case ForNode(
          :final variableName,
          :final collection,
          :final body,
          :final elseBody,
        ):
        final colValue = _evaluateExpression(collection);
        final list = _toList(colValue);

        if (list.isEmpty) {
          if (elseBody.isNotEmpty) {
            buffer.write(evaluate(elseBody));
          }
          return;
        }

        final length = list.length;
        for (var i = 0; i < length; i++) {
          final item = list[i];
          final loopMeta = {
            'index': i + 1,
            'index0': i,
            'revindex': length - i,
            'revindex0': length - i - 1,
            'first': i == 0,
            'last': i == length - 1,
            'length': length,
          };

          context.pushScope({
            variableName: item,
            'loop': loopMeta,
          });

          buffer.write(evaluate(body));
          context.popScope();
        }

      case SetNode(:final name, :final value):
        final val = _evaluateExpression(value);
        context.setVariable(name, val);
    }
  }

  Object? _evaluateExpression(Expression expr) {
    switch (expr) {
      case LiteralExpression(:final value):
        return value;

      case ListLiteralExpression(:final elements):
        return elements.map(_evaluateExpression).toList();

      case VariableExpression(:final name):
        return context.resolve(name);

      case PropertyAccessExpression(:final target, :final property):
        final targetVal = _evaluateExpression(target);
        return context.resolveProperty(targetVal, property);

      case IndexAccessExpression(:final target, :final index):
        final targetVal = _evaluateExpression(target);
        final indexVal = _evaluateExpression(index);
        return context.resolveIndex(targetVal, indexVal);

      case UnaryOpExpression(:final operator, :final operand):
        final val = _evaluateExpression(operand);
        switch (operator) {
          case UnaryOperator.not:
            return !context.isTruthy(val);
        }

      case BinaryOpExpression(:final operator, :final left, :final right):
        final leftVal = _evaluateExpression(left);
        switch (operator) {
          case BinaryOperator.or:
            return context.isTruthy(leftVal) ? leftVal : _evaluateExpression(right);
          case BinaryOperator.and:
            return context.isTruthy(leftVal) ? _evaluateExpression(right) : leftVal;
          case BinaryOperator.equal:
            return _areEqual(leftVal, _evaluateExpression(right));
          case BinaryOperator.notEqual:
            return !_areEqual(leftVal, _evaluateExpression(right));
          case BinaryOperator.less:
            return _compare(leftVal, _evaluateExpression(right)) < 0;
          case BinaryOperator.lessEqual:
            return _compare(leftVal, _evaluateExpression(right)) <= 0;
          case BinaryOperator.greater:
            return _compare(leftVal, _evaluateExpression(right)) > 0;
          case BinaryOperator.greaterEqual:
            return _compare(leftVal, _evaluateExpression(right)) >= 0;
        }
    }
  }

  // ----------------------------------------------------------------------
  // Asynchronous Evaluation
  // ----------------------------------------------------------------------

  Future<String> evaluateAsync(List<KnapNode> nodes) async {
    final buffer = StringBuffer();
    for (final node in nodes) {
      await _evaluateNodeAsync(node, buffer);
    }
    return buffer.toString();
  }

  Future<void> _evaluateNodeAsync(KnapNode node, StringBuffer buffer) async {
    switch (node) {
      case TextNode(:final text):
        buffer.write(text);

      case VariableNode(:final expression, :final filters):
        var value = await _evaluateExpressionAsync(expression);
        for (final filter in filters) {
          final filterArgs = <Object?>[];
          for (final arg in filter.arguments) {
            filterArgs.add(await _evaluateExpressionAsync(arg));
          }
          value = await context.applyFilterAsync(filter.name, value, filterArgs);
        }
        if (value != null) {
          buffer.write(value.toString());
        }

      case IfNode(:final condition, :final thenBranch, :final elifBranches, :final elseBranch):
        final condVal = await _evaluateExpressionAsync(condition);
        if (context.isTruthy(condVal)) {
          buffer.write(await evaluateAsync(thenBranch));
          return;
        }
        for (final elif in elifBranches) {
          final elifVal = await _evaluateExpressionAsync(elif.condition);
          if (context.isTruthy(elifVal)) {
            buffer.write(await evaluateAsync(elif.body));
            return;
          }
        }
        if (elseBranch.isNotEmpty) {
          buffer.write(await evaluateAsync(elseBranch));
        }

      case ForNode(
          :final variableName,
          :final collection,
          :final body,
          :final elseBody,
        ):
        final colValue = await _evaluateExpressionAsync(collection);
        final list = _toList(colValue);

        if (list.isEmpty) {
          if (elseBody.isNotEmpty) {
            buffer.write(await evaluateAsync(elseBody));
          }
          return;
        }

        final length = list.length;
        for (var i = 0; i < length; i++) {
          final item = list[i];
          final loopMeta = {
            'index': i + 1,
            'index0': i,
            'revindex': length - i,
            'revindex0': length - i - 1,
            'first': i == 0,
            'last': i == length - 1,
            'length': length,
          };

          context.pushScope({
            variableName: item,
            'loop': loopMeta,
          });

          buffer.write(await evaluateAsync(body));
          context.popScope();
        }

      case SetNode(:final name, :final value):
        final val = await _evaluateExpressionAsync(value);
        context.setVariable(name, val);
    }
  }

  Future<Object?> _evaluateExpressionAsync(Expression expr) async {
    switch (expr) {
      case LiteralExpression(:final value):
        return value;

      case ListLiteralExpression(:final elements):
        final list = <Object?>[];
        for (final el in elements) {
          list.add(await _evaluateExpressionAsync(el));
        }
        return list;

      case VariableExpression(:final name):
        return context.resolve(name);

      case PropertyAccessExpression(:final target, :final property):
        final targetVal = await _evaluateExpressionAsync(target);
        return context.resolveProperty(targetVal, property);

      case IndexAccessExpression(:final target, :final index):
        final targetVal = await _evaluateExpressionAsync(target);
        final indexVal = await _evaluateExpressionAsync(index);
        return context.resolveIndex(targetVal, indexVal);

      case UnaryOpExpression(:final operator, :final operand):
        final val = await _evaluateExpressionAsync(operand);
        switch (operator) {
          case UnaryOperator.not:
            return !context.isTruthy(val);
        }

      case BinaryOpExpression(:final operator, :final left, :final right):
        final leftVal = await _evaluateExpressionAsync(left);
        switch (operator) {
          case BinaryOperator.or:
            return context.isTruthy(leftVal)
                ? leftVal
                : await _evaluateExpressionAsync(right);
          case BinaryOperator.and:
            return context.isTruthy(leftVal)
                ? await _evaluateExpressionAsync(right)
                : leftVal;
          case BinaryOperator.equal:
            return _areEqual(leftVal, await _evaluateExpressionAsync(right));
          case BinaryOperator.notEqual:
            return !_areEqual(leftVal, await _evaluateExpressionAsync(right));
          case BinaryOperator.less:
            return _compare(leftVal, await _evaluateExpressionAsync(right)) < 0;
          case BinaryOperator.lessEqual:
            return _compare(leftVal, await _evaluateExpressionAsync(right)) <= 0;
          case BinaryOperator.greater:
            return _compare(leftVal, await _evaluateExpressionAsync(right)) > 0;
          case BinaryOperator.greaterEqual:
            return _compare(leftVal, await _evaluateExpressionAsync(right)) >= 0;
        }
    }
  }

  // ----------------------------------------------------------------------
  // Utilities
  // ----------------------------------------------------------------------

  List<Object?> _toList(Object? val) {
    if (val == null) return const [];
    if (val is List) return val;
    if (val is Iterable) return val.toList();
    if (val is Map) return val.entries.toList();
    return [val];
  }

  bool _areEqual(Object? a, Object? b) {
    if (a == b) return true;
    if (a == null || b == null) return false;

    // Loose equality for numbers
    if (a is num && b is num) {
      return a == b;
    }
    // String to number comparison if possible
    if (a is num && b is String) {
      return a == num.tryParse(b);
    }
    if (a is String && b is num) {
      return num.tryParse(a) == b;
    }

    return a.toString() == b.toString();
  }

  int _compare(Object? a, Object? b) {
    if (a is num && b is num) {
      return a.compareTo(b);
    }
    if (a is Comparable && b is Comparable) {
      try {
        return a.compareTo(b);
      } catch (_) {}
    }
    return (a?.toString() ?? '').compareTo(b?.toString() ?? '');
  }
}
