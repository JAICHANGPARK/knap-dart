import 'dart:convert';
import 'dart:math' as math;
import 'filter.dart';

Object? _resolveNestedPath(Object? item, String path) {
  var current = item;
  final segments = path
      .split(RegExp(r'[.\[\]]'))
      .where((s) => s.isNotEmpty)
      .toList();
  for (final seg in segments) {
    if (current is Map) {
      current = current[seg];
    } else if (current is List) {
      final idx = int.tryParse(seg);
      current = (idx != null && idx >= 0 && idx < current.length)
          ? current[idx]
          : null;
    } else {
      return null;
    }
  }
  return current;
}

Object? _evaluateArrowValue(Object? item, String argName, String expr) {
  final trimmed = expr.trim();
  if (trimmed == argName) return item;
  final prefix = '$argName.';
  if (trimmed.startsWith(prefix)) {
    return _resolveNestedPath(item, trimmed.substring(prefix.length));
  }
  return trimmed.replaceAll(RegExp('^[\'"]|[\'"]\$'), '');
}

Object? _evaluateArrowItem(Object? item, String argName, String rawExpr) {
  var expr = rawExpr.trim();
  if (expr.startsWith('(') && expr.endsWith(')')) {
    expr = expr.substring(1, expr.length - 1).trim();
  }
  if (expr.startsWith('{') && expr.endsWith('}')) {
    final body = expr.substring(1, expr.length - 1).trim();
    final result = <String, Object?>{};
    if (body.isNotEmpty) {
      for (final part in body.split(',')) {
        final colonIdx = part.indexOf(':');
        if (colonIdx > 0) {
          final rawKey = part.substring(0, colonIdx).trim();
          final cleanKey = rawKey.replaceAll(RegExp('^[\'"]|[\'"]\$'), '');
          final valExpr = part.substring(colonIdx + 1).trim();
          result[cleanKey] = _evaluateArrowValue(item, argName, valExpr);
        }
      }
    }
    return result;
  }
  if ((expr.startsWith('"') && expr.endsWith('"')) ||
      (expr.startsWith("'") && expr.endsWith("'"))) {
    final inner = expr.substring(1, expr.length - 1);
    return inner.replaceAll('\${$argName}', item?.toString() ?? '');
  }
  return _evaluateArrowValue(item, argName, expr);
}

/// Collection manipulation, filtering, sorting, and projection filters.
final Map<String, KnapFilter> collectionFilters = {
  'default': (val, args) {
    final fallback = args.isNotEmpty ? args[0] : '';
    if (val == null) return fallback;
    if (val is String && val.trim().isEmpty) return fallback;
    if (val is Iterable && val.isEmpty) return fallback;
    if (val is Map && val.isEmpty) return fallback;
    return val;
  },
  'length': (val, args) {
    if (val == null) return 0;
    if (val is String) return val.length;
    if (val is Iterable) return val.length;
    if (val is Map) return val.length;
    return 0;
  },
  'first': (val, args) {
    if (val is Iterable && val.isNotEmpty) return val.first;
    if (val is String && val.isNotEmpty) return val[0];
    return null;
  },
  'last': (val, args) {
    if (val is Iterable && val.isNotEmpty) return val.last;
    if (val is String && val.isNotEmpty) return val[val.length - 1];
    return null;
  },
  'join': (val, args) {
    final sep = args.isNotEmpty ? args[0]?.toString() ?? ', ' : ', ';
    if (val is Iterable) {
      return val.map((e) => e?.toString() ?? '').join(sep);
    }
    return val?.toString() ?? '';
  },
  'sort': (val, args) {
    if (val is! Iterable) return val;
    final copy = val.toList();
    String? property;
    var desc = false;
    if (args.isNotEmpty) {
      final firstArg = args[0]?.toString() ?? '';
      if (args.length == 1 &&
          (firstArg.toLowerCase() == 'asc' ||
              firstArg.toLowerCase() == 'desc')) {
        desc = firstArg.toLowerCase() == 'desc';
      } else {
        property = firstArg.isEmpty ? null : firstArg;
        if (args.length > 1) {
          desc = args[1]?.toString().toLowerCase() == 'desc';
        }
      }
    }
    copy.sort((a, b) {
      final leftVal = property != null ? _resolveNestedPath(a, property) : a;
      final rightVal = property != null ? _resolveNestedPath(b, property) : b;
      int cmp;
      if (leftVal is num && rightVal is num) {
        cmp = leftVal.compareTo(rightVal);
      } else {
        cmp = (leftVal?.toString() ?? '').compareTo(rightVal?.toString() ?? '');
      }
      return desc ? -cmp : cmp;
    });
    return copy;
  },
  'reverse': (val, args) {
    if (val is Map) {
      return Map.fromEntries(val.entries.toList().reversed);
    }
    if (val is List) {
      return val.reversed.toList();
    }
    if (val is Iterable) {
      return val.toList().reversed.toList();
    }
    if (val is String) {
      return val.split('').reversed.join('');
    }
    return val;
  },
  'slice': (val, args) {
    var start = 0;
    int? end;
    if (args.isNotEmpty) {
      final firstArg = args[0];
      if (firstArg is num) {
        start = firstArg.toInt();
      } else if (firstArg is String && firstArg.contains(',')) {
        final parts = firstArg.split(',');
        start = int.tryParse(parts[0].trim()) ?? 0;
        if (parts.length > 1) {
          end = int.tryParse(parts[1].trim());
        }
      } else if (firstArg != null) {
        start = int.tryParse(firstArg.toString()) ?? 0;
      }
    }
    if (args.length > 1) {
      final secondArg = args[1];
      if (secondArg is num) {
        end = secondArg.toInt();
      } else if (secondArg != null) {
        end = int.tryParse(secondArg.toString());
      }
    }

    if (val is List) {
      final len = val.length;
      final effectiveStart =
          start < 0 ? math.max(0, len + start) : math.min(len, start);
      final effectiveEnd = end == null
          ? len
          : end < 0
              ? math.max(0, len + end)
              : math.min(len, end);
      final s = math.min(effectiveStart, effectiveEnd);
      final e = math.max(s, effectiveEnd);
      return val.sublist(s, e);
    }
    if (val is String) {
      final len = val.length;
      final effectiveStart =
          start < 0 ? math.max(0, len + start) : math.min(len, start);
      final effectiveEnd = end == null
          ? len
          : end < 0
              ? math.max(0, len + end)
              : math.min(len, end);
      final s = math.min(effectiveStart, effectiveEnd);
      final e = math.max(s, effectiveEnd);
      return val.substring(s, e);
    }
    return val;
  },
  'unique': (val, args) {
    if (val is Iterable) {
      final seen = <String>{};
      final res = <dynamic>[];
      for (final item in val) {
        final key = jsonEncode(item);
        if (seen.add(key)) {
          res.add(item);
        }
      }
      return res;
    }
    if (val is Map) {
      final seenValues = <String>{};
      final reversedEntries = val.entries.toList().reversed;
      final keptEntries = <MapEntry>[];
      for (final entry in reversedEntries) {
        final key = jsonEncode(entry.value);
        if (seenValues.add(key)) {
          keptEntries.add(entry);
        }
      }
      return Map.fromEntries(keptEntries.reversed);
    }
    return val;
  },
  'merge': (val, args) {
    if (args.isEmpty) return val;
    if (val is List) {
      final res = List<Object?>.from(val);
      for (final other in args) {
        if (other is Iterable) {
          res.addAll(other);
        } else if (other != null) {
          res.add(other);
        }
      }
      return res;
    }
    if (val is Map) {
      final res = Map<dynamic, dynamic>.from(val);
      for (final other in args) {
        if (other is Map) {
          res.addAll(other);
        }
      }
      return res;
    }
    return val;
  },
  'split': (val, args) {
    final str = val?.toString() ?? '';
    if (args.isEmpty) return str.split('');
    final pattern = args[0]?.toString() ?? '';
    if (pattern.isEmpty) return str.split('');
    if (pattern.startsWith('[') && pattern.endsWith(']')) {
      try {
        return str.split(RegExp(pattern));
      } catch (_) {}
    }
    if (pattern.startsWith('/') && pattern.endsWith('/') && pattern.length > 2) {
      try {
        return str.split(RegExp(pattern.substring(1, pattern.length - 1)));
      } catch (_) {}
    }
    return str.split(pattern);
  },
  'where': (val, args) {
    if (val is! Iterable || args.isEmpty) return val;
    final key = args[0]?.toString() ?? '';
    final hasExpected = args.length > 1;
    final expected = hasExpected ? args[1] : null;

    return val.where((item) {
      if (item is Map) {
        final itemVal = _resolveNestedPath(item, key);
        if (hasExpected) {
          return itemVal == expected;
        }
        return itemVal != null && itemVal != false && itemVal != '';
      }
      return false;
    }).toList();
  },
  'map': (val, args) {
    if (val is! Iterable || args.isEmpty) return val;
    final key = args[0]?.toString() ?? '';
    final arrowMatch = RegExp(r'^\s*(\w+)\s*=>\s*(.+)$').firstMatch(key);
    if (arrowMatch != null) {
      final argName = arrowMatch.group(1)!;
      final expr = arrowMatch.group(2)!;
      return val.map((item) => _evaluateArrowItem(item, argName, expr)).toList();
    }
    return val.map((item) => _resolveNestedPath(item, key)).toList();
  },
  'compact': (val, args) {
    if (val is Map) {
      final res = <dynamic, dynamic>{};
      for (final entry in val.entries) {
        final v = entry.value;
        if (v != null && v != '') {
          res[entry.key] = v;
        }
      }
      return res;
    }
    if (val is Iterable) {
      return val.where((e) => e != null && e != '').toList();
    }
    return val;
  },
  'nth': (val, args) {
    if (val is! Iterable || args.isEmpty) return val;
    final list = val.toList();
    final param = args[0]?.toString().trim() ?? '';
    if (param.isEmpty) return list;

    // Multi-arg basis or Colon pattern: nth:2,3:4 or nth:1,2:5
    var basis = 1;
    var positions = <int>{};
    if (args.length > 1) {
      basis = int.tryParse(args.last.toString()) ?? 1;
      positions = args
          .sublist(0, args.length - 1)
          .map((n) => int.tryParse(n.toString()) ?? 0)
          .where((n) => n > 0)
          .toSet();
    } else if (param.contains(':')) {
      final parts = param.split(':');
      positions = parts[0]
          .split(',')
          .map((n) => int.tryParse(n.trim()) ?? 0)
          .where((n) => n > 0)
          .toSet();
      basis = int.tryParse(parts[1].trim()) ?? 1;
    }
    if (positions.isNotEmpty) {
      final result = <Object?>[];
      for (var i = 0; i < list.length; i++) {
        final posInGroup = (i % basis) + 1;
        if (positions.contains(posInGroup)) {
          result.add(list[i]);
        }
      }
      return result;
    }

    // Simple number: "7"
    if (RegExp(r'^\d+$').hasMatch(param)) {
      final pos = int.parse(param);
      if (pos >= 1 && pos <= list.length) {
        return [list[pos - 1]];
      }
      return const [];
    }

    // Multiplier: "2n"
    if (RegExp(r'^\d+n$').hasMatch(param)) {
      final step = int.parse(param.replaceAll('n', ''));
      if (step <= 0) return const [];
      final result = <Object?>[];
      for (var i = 0; i < list.length; i++) {
        if ((i + 1) % step == 0) {
          result.add(list[i]);
        }
      }
      return result;
    }

    // Offset: "n+3"
    final nMatch = RegExp(r'^n\+(\d+)$').firstMatch(param);
    if (nMatch != null) {
      final offset = int.parse(nMatch.group(1)!);
      final result = <Object?>[];
      for (var i = 0; i < list.length; i++) {
        if ((i + 1) >= offset) {
          result.add(list[i]);
        }
      }
      return result;
    }

    return list;
  },
  'object': (val, args) {
    if (val == null) return val;
    Map map;
    if (val is Map) {
      map = val;
    } else {
      try {
        final decoded = jsonDecode(val.toString());
        if (decoded is Map) {
          map = decoded;
        } else {
          return val;
        }
      } catch (_) {
        return val;
      }
    }

    final mode = args.isNotEmpty ? args[0]?.toString().toLowerCase() : 'keys';
    switch (mode) {
      case 'keys':
        return map.keys.toList();
      case 'values':
        return map.values.toList();
      case 'array':
        return map.entries.map((e) => [e.key, e.value]).toList();
      default:
        return map;
    }
  },
};
