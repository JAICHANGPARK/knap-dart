import '../errors/exceptions.dart';
import '../filters/filter.dart';

class KnapScope {
  final Map<String, Object?> variables;
  final KnapScope? parent;

  KnapScope(this.variables, [this.parent]);

  Object? lookup(String name) {
    if (variables.containsKey(name)) {
      return variables[name];
    }
    if (parent != null) {
      return parent!.lookup(name);
    }
    return null;
  }

  void set(String name, Object? value) {
    variables[name] = value;
  }
}

class KnapContext {
  KnapScope _currentScope;
  final FilterRegistry filterRegistry;

  KnapContext({
    Map<String, Object?>? variables,
    FilterRegistry? filterRegistry,
  })  : _currentScope = KnapScope(variables ?? {}),
        filterRegistry = filterRegistry ?? FilterRegistry();

  void setVariable(String name, Object? value) {
    _currentScope.set(name, value);
  }

  void pushScope(Map<String, Object?> newVariables) {
    _currentScope = KnapScope(newVariables, _currentScope);
  }

  void popScope() {
    if (_currentScope.parent != null) {
      _currentScope = _currentScope.parent!;
    }
  }

  Object? resolve(String name) => _currentScope.lookup(name);

  Object? resolveProperty(Object? target, String property) {
    if (target == null) return null;

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
      return target[index] ?? target[index?.toString()];
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

  bool isTruthy(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  Object? applyFilter(String name, Object? value, List<Object?> args) {
    final filter = filterRegistry.getSync(name);
    if (filter == null) {
      throw KnapEvaluationException('Filter "$name" is not defined or is async-only');
    }
    return filter(value, args);
  }

  Future<Object?> applyFilterAsync(String name, Object? value, List<Object?> args) async {
    final filter = filterRegistry.getAsync(name);
    if (filter == null) {
      throw KnapEvaluationException('Filter "$name" is not defined');
    }
    return await filter(value, args);
  }
}
