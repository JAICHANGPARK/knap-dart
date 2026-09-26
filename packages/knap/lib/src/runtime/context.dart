import '../errors/exceptions.dart';
import '../filters/filter.dart';

/// An isolated lexical scope maintaining a map of variables with a pointer to its enclosing parent scope.
class KnapScope {
  /// The local variables accessible in this scope.
  final Map<String, Object?> variables;

  /// The enclosing parent scope, or `null` if this is the root scope.
  final KnapScope? parent;

  /// Creates a [KnapScope] with [variables] and an optional [parent] scope.
  KnapScope(this.variables, [this.parent]);

  /// Looks up a variable by [name] in this scope or recursively in ancestor scopes.
  Object? lookup(String name) {
    if (variables.containsKey(name)) {
      return variables[name];
    }
    if (parent != null) {
      return parent!.lookup(name);
    }
    return null;
  }

  /// Sets the value of a variable [name] in the local scope.
  void set(String name, Object? value) {
    variables[name] = value;
  }
}

/// The execution context for template rendering, managing variable scopes and filter execution.
class KnapContext {
  KnapScope _currentScope;

  /// The active filter registry used to look up and execute filters.
  final FilterRegistry filterRegistry;

  /// Creates a [KnapContext] with optional initial [variables] and a [filterRegistry].
  KnapContext({
    Map<String, Object?>? variables,
    FilterRegistry? filterRegistry,
  })  : _currentScope = KnapScope(variables ?? {}),
        filterRegistry = filterRegistry ?? FilterRegistry();

  /// Sets a variable [name] to [value] in the innermost active scope.
  void setVariable(String name, Object? value) {
    _currentScope.set(name, value);
  }

  /// Pushes a new child lexical scope with [newVariables].
  void pushScope(Map<String, Object?> newVariables) {
    _currentScope = KnapScope(newVariables, _currentScope);
  }

  /// Pops the topmost lexical scope, returning to its parent.
  void popScope() {
    if (_currentScope.parent != null) {
      _currentScope = _currentScope.parent!;
    }
  }

  /// Resolves the value of variable [name] from the scope hierarchy.
  Object? resolve(String name) => _currentScope.lookup(name);

  /// Resolves a named [property] on [target] (such as Map keys, List lengths, or String lengths).
  Object? resolveProperty(Object? target, String property) {
    if (target == null) return null;

    if (target is MapEntry) {
      if (property == 'key') return target.key;
      if (property == 'value') return target.value;
      return null;
    }

    if (target is Map) {
      if (target.containsKey(property)) {
        return target[property];
      }
      // Also try string key if target has dynamic/object keys
      for (final entry in target.entries) {
        if (entry.key.toString() == property) {
          return entry.value;
        }
      }
      if (property == 'length') return target.length;
      if (property == 'keys') return target.keys.toList();
      if (property == 'values') return target.values.toList();
      return null;
    }

    if (target is List) {
      if (property == 'length') return target.length;
      if (property == 'first' && target.isNotEmpty) return target.first;
      if (property == 'last' && target.isNotEmpty) return target.last;
      final intIndex = int.tryParse(property);
      if (intIndex != null && intIndex >= 0 && intIndex < target.length) {
        return target[intIndex];
      }
      return null;
    }

    if (target is String) {
      if (property == 'length') return target.length;
      return null;
    }

    return null;
  }

  /// Resolves an element on [target] accessed by [index] or key.
  Object? resolveIndex(Object? target, Object? index) {
    if (target == null) return null;

    if (target is List) {
      final intIndex = index is num ? index.toInt() : int.tryParse(index?.toString() ?? '');
      if (intIndex != null && intIndex >= 0 && intIndex < target.length) {
        return target[intIndex];
      }
      return null;
    }

    if (target is Map) {
      if (target.containsKey(index)) return target[index];
      final strKey = index?.toString();
      if (target.containsKey(strKey)) return target[strKey];
      final intKey = int.tryParse(strKey ?? '');
      if (intKey != null && target.containsKey(intKey)) return target[intKey];
      return null;
    }

    if (target is String) {
      final intIndex = index is num ? index.toInt() : int.tryParse(index?.toString() ?? '');
      if (intIndex != null && intIndex >= 0 && intIndex < target.length) {
        return target[intIndex];
      }
      return null;
    }

    return null;
  }

  /// Whether [value] evaluates to truthy according to Knap template rules.
  ///
  /// `false`, `0`, `null`, empty strings, empty lists, and empty maps evaluate to `false`.
  bool isTruthy(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  /// Applies a synchronous filter by [name] with input [value] and [args].
  ///
  /// Throws a [KnapEvaluationException] if the filter is not defined or is async-only.
  Object? applyFilter(String name, Object? value, List<Object?> args) {
    final filter = filterRegistry.getSync(name);
    if (filter == null) {
      throw KnapEvaluationException('Filter "$name" is not defined or is async-only');
    }
    return filter(value, args);
  }

  /// Applies an asynchronous filter by [name] with input [value] and [args].
  ///
  /// Throws a [KnapEvaluationException] if the filter is not defined.
  Future<Object?> applyFilterAsync(String name, Object? value, List<Object?> args) async {
    final filter = filterRegistry.getAsync(name);
    if (filter == null) {
      throw KnapEvaluationException('Filter "$name" is not defined');
    }
    return await filter(value, args);
  }
}
