typedef KnapFilter = Object? Function(Object? value, List<Object?> args);
typedef KnapAsyncFilter = Future<Object?> Function(Object? value, List<Object?> args);

class FilterRegistry {
  final Map<String, KnapFilter> _syncFilters = {};
  final Map<String, KnapAsyncFilter> _asyncFilters = {};

  FilterRegistry([Map<String, KnapFilter>? initialFilters]) {
    if (initialFilters != null) {
      _syncFilters.addAll(initialFilters);
    }
  }

  void register(String name, KnapFilter filter) {
    _syncFilters[name] = filter;
  }

  void registerAsync(String name, KnapAsyncFilter filter) {
    _asyncFilters[name] = filter;
  }

  KnapFilter? getSync(String name) => _syncFilters[name];

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

  bool has(String name) => _syncFilters.containsKey(name) || _asyncFilters.containsKey(name);

  Map<String, KnapFilter> get allSync => Map.unmodifiable(_syncFilters);
}
