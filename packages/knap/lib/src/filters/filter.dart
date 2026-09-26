/// A synchronous filter function taking an input [value] and positional [args].
typedef KnapFilter = Object? Function(Object? value, List<Object?> args);

/// An asynchronous filter function taking an input [value] and positional [args].
typedef KnapAsyncFilter = Future<Object?> Function(Object? value, List<Object?> args);

/// A registry that stores and resolves synchronous and asynchronous Knap filters.
class FilterRegistry {
  final Map<String, KnapFilter> _syncFilters = {};
  final Map<String, KnapAsyncFilter> _asyncFilters = {};

  /// Creates a registry optionally pre-populated with [initialFilters].
  FilterRegistry([Map<String, KnapFilter>? initialFilters]) {
    if (initialFilters != null) {
      _syncFilters.addAll(initialFilters);
    }
  }

  /// Registers a synchronous filter with the given [name].
  void register(String name, KnapFilter filter) {
    _syncFilters[name] = filter;
  }

  /// Registers an asynchronous filter with the given [name].
  void registerAsync(String name, KnapAsyncFilter filter) {
    _asyncFilters[name] = filter;
  }

  /// Retrieves a registered synchronous filter by [name], or `null` if not found.
  KnapFilter? getSync(String name) => _syncFilters[name];

  /// Retrieves a registered asynchronous filter by [name], wrapping sync filters if needed.
  KnapAsyncFilter? getAsync(String name) {
    if (_asyncFilters.containsKey(name)) {
      return _asyncFilters[name];
    }
    if (_syncFilters.containsKey(name)) {
      final sync = _syncFilters[name]!;
      return (val, args) async => sync(val, args);
    }
    return null;
  }

  /// Whether a filter with the given [name] is registered.
  bool has(String name) => _syncFilters.containsKey(name) || _asyncFilters.containsKey(name);

  /// An unmodifiable view of all registered synchronous filters.
  Map<String, KnapFilter> get allSync => Map.unmodifiable(_syncFilters);
}
