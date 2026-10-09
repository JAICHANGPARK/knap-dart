import 'dart:convert';
import 'dart:math' as math;
import 'filter.dart';
import 'html_filters.dart';

List<String> _splitWords(String str) {
  if (str.isEmpty) return [];
  // Split on transition from lower to upper case or whitespace/dash/underscore
  final parts = <String>[];
  final regex = RegExp(r'[A-Z]?[a-z0-9]+|[A-Z]+(?![a-z0-9])');
  for (final match in regex.allMatches(str)) {
    parts.add(match.group(0)!);
  }
  return parts;
}

DateTime? _parseDateTime(Object? val) {
  if (val == null) return null;
  if (val is DateTime) return val;
  if (val is num) {
    // If epoch seconds vs milliseconds
    final intVal = val.toInt();
    if (intVal < 10000000000) {
      return DateTime.fromMillisecondsSinceEpoch(intVal * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(intVal);
  }
  final str = val.toString().trim();
  if (str.toLowerCase() == 'now' || str.toLowerCase() == 'today') {
    return DateTime.now();
  }
  return DateTime.tryParse(str);
}

String _formatDate(DateTime dt, String format) {
  final yyyy = dt.year.toString().padLeft(4, '0');
  final yy = yyyy.substring(2);
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  final ss = dt.second.toString().padLeft(2, '0');

  return format
      .replaceAll('YYYY', yyyy)
      .replaceAll('YY', yy)
      .replaceAll('MM', mm)
      .replaceAll('DD', dd)
      .replaceAll('HH', hh)
      .replaceAll('mm', min)
      .replaceAll('ss', ss);
}

String _yamlKeyText(String key) {
  final validUnquoted =
      RegExp(r'^[a-zA-Z_][\w-]*$').hasMatch(key) &&
      !RegExp(
        r'^(?:true|false|null|yes|no|on|off|y|n)$',
        caseSensitive: false,
      ).hasMatch(key);
  return validUnquoted ? key : jsonEncode(key);
}

String _yamlFlow(Object? value) => jsonEncode(value);

String _yamlBlock(Object? value) {
  if (value is List) {
    if (value.isEmpty) return '[]';
    return value
        .map((item) => '- ${_yamlBlock(item).replaceAll('\n', '\n  ')}')
        .join('\n');
  }
  if (value is Map) {
    if (value.isEmpty) return '{}';
    return value.entries.map((entry) {
      final k = _yamlKeyText(entry.key.toString());
      final v = entry.value;
      final isNestedBlock =
          (v is List && v.isNotEmpty) || (v is Map && v.isNotEmpty);
      if (isNestedBlock) {
        return '$k:\n  ${_yamlBlock(v).replaceAll('\n', '\n  ')}';
      }
      return '$k: ${_yamlBlock(v)}';
    }).join('\n');
  }
  return _yamlFlow(value);
}

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

Object? _evaluateArrowValue(Object? item, String argName, String expr) {
  final trimmed = expr.trim();
  if (trimmed == argName) return item;
  final prefix = '$argName.';
  if (trimmed.startsWith(prefix)) {
    return _resolveNestedPath(item, trimmed.substring(prefix.length));
  }
  return trimmed.replaceAll(RegExp('^[\'"]|[\'"]\$'), '');
}

/// The built-in library of standard string, collection, math, date, and utility filters.
///
/// Includes string casing (`upper`, `lower`, `camel`, `kebab`, `snake`),
/// collection transforms (`map`, `where`, `sort`, `unique`, `join`, `slice`),
/// date formatting (`date`, `date_modify`, `duration`), and YAML/JSON
/// serialization (`yaml`, `yaml_property`, `json`):
///
/// ```dart
/// final names = standardFilters['map']!(
///   [
///     {'name': 'Alice'},
///     {'name': 'Bob'},
///   ],
///   ['item => item.name'],
/// );
/// // ['Alice', 'Bob']
/// ```
final Map<String, KnapFilter> standardFilters = {
  // String filters
  'trim': (val, args) => val?.toString().trim() ?? '',
  'upper': (val, args) => val?.toString().toUpperCase() ?? '',
  'lower': (val, args) => val?.toString().toLowerCase() ?? '',
  'capitalize': (val, args) {
    final str = val?.toString() ?? '';
    if (str.isEmpty) return '';
    return str[0].toUpperCase() + str.substring(1).toLowerCase();
  },
  'title': (val, args) {
    final str = val?.toString() ?? '';
    if (str.isEmpty) return '';
    return str.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  },
  'slug': (val, args) {
    final str = val?.toString() ?? '';
    final slug = str
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s_-]'), '')
        .replaceAll(RegExp(r'[\s_]+'), '-');
    return slug;
  },

  // Case filters
  'snake': (val, args) {
    final words = _splitWords(val?.toString() ?? '');
    return words.map((w) => w.toLowerCase()).join('_');
  },
  'camel': (val, args) {
    final words = _splitWords(val?.toString() ?? '');
    if (words.isEmpty) return '';
    return words.first.toLowerCase() +
        words
            .skip(1)
            .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
            .join('');
  },
  'kebab': (val, args) {
    final words = _splitWords(val?.toString() ?? '');
    return words.map((w) => w.toLowerCase()).join('-');
  },
  'pascal': (val, args) {
    final words = _splitWords(val?.toString() ?? '');
    return words
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join('');
  },

  'replace': (val, args) {
    var str = val?.toString() ?? '';
    if (args.isEmpty) return str;
    for (var i = 0; i < args.length; i += 2) {
      final from = args[i]?.toString() ?? '';
      final to = (i + 1 < args.length) ? (args[i + 1]?.toString() ?? '') : '';
      final regexMatch = RegExp(r'^/(.+)/([gimsuy]*)$').firstMatch(from);
      if (regexMatch != null) {
        final pattern = regexMatch.group(1)!;
        final flags = regexMatch.group(2)!;
        final reg = RegExp(
          pattern,
          caseSensitive: !flags.contains('i'),
          multiLine: flags.contains('m'),
          dotAll: flags.contains('s'),
        );
        str = str.replaceAll(reg, to);
      } else {
        str = str.replaceAll(from, to);
      }
    }
    return str;
  },
  'default': (val, args) {
    final fallback = args.isNotEmpty ? args[0] : '';
    if (val == null) return fallback;
    if (val is String && val.trim().isEmpty) return fallback;
    if (val is Iterable && val.isEmpty) return fallback;
    if (val is Map && val.isEmpty) return fallback;
    return val;
  },
  'truncate': (val, args) {
    final str = val?.toString() ?? '';
    final maxLen = args.isNotEmpty
        ? (args[0] is num
              ? (args[0] as num).toInt()
              : int.tryParse(args[0]?.toString() ?? '') ?? 50)
        : 50;
    final suffix = args.length > 1 ? args[1]?.toString() ?? '...' : '...';
    if (maxLen <= 0) return '';
    if (str.length <= maxLen) return str;
    return '${str.substring(0, maxLen)}$suffix';
  },
  'truncatewords': (val, args) {
    final str = val?.toString() ?? '';
    final limit = args.isNotEmpty
        ? (args[0] is num
              ? (args[0] as num).toInt()
              : int.tryParse(args[0]?.toString() ?? '') ?? 0)
        : 0;
    final suffix = args.length > 1 ? args[1]?.toString() ?? '…' : '…';
    if (limit <= 0) return '';
    final matches = RegExp(r'\S+').allMatches(str).toList();
    if (matches.length <= limit) return str;
    final finalWord = matches[limit - 1];
    return '${str.substring(0, finalWord.end)}$suffix';
  },

  // Collection filters
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
    final start = args.isNotEmpty && args[0] is num
        ? (args[0] as num).toInt()
        : 0;
    final end = args.length > 1 && args[1] is num
        ? (args[1] as num).toInt()
        : null;

    if (val is List) {
      final effectiveStart = start.clamp(0, val.length);
      final effectiveEnd = end != null
          ? end.clamp(effectiveStart, val.length)
          : val.length;
      return val.sublist(effectiveStart, effectiveEnd);
    }
    if (val is String) {
      final effectiveStart = start.clamp(0, val.length);
      final effectiveEnd = end != null
          ? end.clamp(effectiveStart, val.length)
          : val.length;
      return val.substring(effectiveStart, effectiveEnd);
    }
    return val;
  },
  'unique': (val, args) {
    if (val is Iterable) {
      return val.toSet().toList();
    }
    return val;
  },
  'merge': (val, args) {
    if (args.isEmpty) return val;
    final other = args[0];
    if (val is List) {
      final res = List<Object?>.from(val);
      if (other is Iterable) {
        res.addAll(other);
      } else if (other != null) {
        res.add(other);
      }
      return res;
    }
    if (val is Map && other is Map) {
      return {...val, ...other};
    }
    return val;
  },
  'yaml': (val, args) {
    if (val == null) return 'null';
    final isFlow =
        args.isNotEmpty && args[0]?.toString().toLowerCase() == 'flow';
    if (val is List || val is Map) {
      return isFlow ? _yamlFlow(val) : _yamlBlock(val);
    }
    final str = val.toString();
    if (str.isEmpty) return "''";
    if (isFlow) return _yamlFlow(val);
    if (RegExp(r'[:#\[\]{}&*!|>"%@`]|\n').hasMatch(str) ||
        str.startsWith(' ') ||
        str.endsWith(' ')) {
      return jsonEncode(str);
    }
    return str;
  },
  'yaml_property': (val, args) {
    if (args.isEmpty) return val?.toString() ?? '';
    final key = args[0]?.toString().trim() ?? '';
    if (key.isEmpty) return val?.toString() ?? '';
    final formattedKey = _yamlKeyText(key);
    if (val is List || val is Map) {
      return _yamlBlock({key: val});
    }
    if (val == null || val is bool || val is num) {
      return '$formattedKey: ${_yamlFlow(val)}';
    }
    return '$formattedKey: ${_yamlFlow(val.toString())}';
  },
  'hard_break': (val, args) {
    final str = val?.toString() ?? '';
    return str.replaceAll('\n', '  \n');
  },
  'json': (val, args) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(val);
    } catch (_) {
      return val?.toString() ?? '';
    }
  },

  // Date filters
  'date': (val, args) {
    final dt = _parseDateTime(val);
    if (dt == null) return val?.toString() ?? '';
    final format = args.isNotEmpty
        ? args[0]?.toString() ?? 'YYYY-MM-DD'
        : 'YYYY-MM-DD';
    return _formatDate(dt, format);
  },
  'date_modify': (val, args) {
    final dt = _parseDateTime(val);
    if (dt == null || args.isEmpty) return val?.toString() ?? '';

    final modifier = args[0]?.toString().trim() ?? '';
    final match = RegExp(
      r'^([+-]?\d+)\s*(year|month|week|day|hour|minute|second)s?$',
      caseSensitive: false,
    ).firstMatch(modifier);

    if (match == null) return _formatDate(dt, 'YYYY-MM-DD');

    final amount = int.tryParse(match.group(1)!) ?? 0;
    final unit = match.group(2)!.toLowerCase();

    DateTime modified;
    switch (unit) {
      case 'year':
        modified = DateTime(
          dt.year + amount,
          dt.month,
          dt.day,
          dt.hour,
          dt.minute,
          dt.second,
        );
        break;
      case 'month':
        modified = DateTime(
          dt.year,
          dt.month + amount,
          dt.day,
          dt.hour,
          dt.minute,
          dt.second,
        );
        break;
      case 'week':
        modified = dt.add(Duration(days: amount * 7));
        break;
      case 'day':
        modified = dt.add(Duration(days: amount));
        break;
      case 'hour':
        modified = dt.add(Duration(hours: amount));
        break;
      case 'minute':
        modified = dt.add(Duration(minutes: amount));
        break;
      case 'second':
        modified = dt.add(Duration(seconds: amount));
        break;
      default:
        modified = dt;
    }

    final format = args.length > 1
        ? args[1]?.toString() ?? 'YYYY-MM-DD'
        : 'YYYY-MM-DD';
    return _formatDate(modified, format);
  },

  // Additional String / System Filters
  'split': (val, args) {
    final str = val?.toString() ?? '';
    final delimiter = args.isNotEmpty ? args[0]?.toString() ?? ',' : ',';
    return str.split(delimiter);
  },
  'indent': (val, args) {
    final str = val?.toString() ?? '';
    final width = args.isNotEmpty && args[0] is num
        ? (args[0] as num).toInt()
        : 2;
    final indentStr = ' ' * width;
    return str
        .split('\n')
        .map((line) => line.isEmpty ? line : '$indentStr$line')
        .join('\n');
  },
  'encode_uri': (val, args) => Uri.encodeComponent(val?.toString() ?? ''),
  'decode_uri': (val, args) => Uri.decodeComponent(val?.toString() ?? ''),
  'safe_name': (val, args) {
    final str = val?.toString() ?? '';
    final arg = args.isNotEmpty ? args[0]?.toString() : null;
    final lowerArg = arg?.toLowerCase();
    if (lowerArg == 'windows' || lowerArg == 'mac' || lowerArg == 'linux') {
      var sanitized = str.replaceAll(RegExp(r'[#|\^\[\]]'), '');
      if (lowerArg == 'windows') {
        sanitized = sanitized
            .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
            .replaceAllMapped(
              RegExp(
                r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\..*)?$',
                caseSensitive: false,
              ),
              (m) => '_${m.group(1)}${m.group(2) ?? ''}',
            )
            .replaceAll(RegExp(r'[\s.]+$'), '');
      } else if (lowerArg == 'mac') {
        sanitized = sanitized
            .replaceAll(RegExp(r'[/:\x00-\x1F]'), '')
            .replaceFirst(RegExp(r'^\.'), '_');
      } else {
        sanitized = sanitized
            .replaceAll(RegExp(r'[/\x00-\x1F]'), '')
            .replaceFirst(RegExp(r'^\.'), '_');
      }
      sanitized = sanitized.replaceFirst(RegExp(r'^\.+'), '');
      if (sanitized.length > 245) {
        sanitized = sanitized.substring(0, 245);
      }
      return sanitized.isEmpty ? 'Untitled' : sanitized;
    }
    final replacement = arg ?? '';
    return str.replaceAll(RegExp(r'[/\\?%*:|"<>#^\[\]]'), replacement).trim();
  },
  'strip_tags': (val, args) {
    final str = val?.toString() ?? '';
    if (str.isEmpty) return '';
    return str
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .trim();
  },
  'remove_html': (val, args) => standardFilters['strip_tags']!(val, args),
  'remove_tags': (val, args) => standardFilters['strip_tags']!(val, args),
  'html_to_json': htmlToJsonFilter,

  // Additional Collection Filters
  'where': (val, args) {
    if (val is! Iterable || args.isEmpty) return val;
    final key = args[0]?.toString() ?? '';
    final hasExpected = args.length > 1;
    final expected = hasExpected ? args[1] : null;

    return val.where((item) {
      if (item is Map) {
        final itemVal = _resolveNestedPath(item, key);
        if (hasExpected) {
          if (expected == null) return itemVal == null;
          return itemVal?.toString() == expected.toString();
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
    if (val is! Iterable) return val;
    return val.where((e) => e != null && e != '' && e != false).toList();
  },

  // Math & Number Filters
  'sum': (val, args) {
    if (val is! Iterable) return 0;
    num total = 0;
    for (final item in val) {
      if (item is num) {
        total += item;
      } else if (item != null) {
        final parsed = num.tryParse(item.toString());
        if (parsed != null) total += parsed;
      }
    }
    if (total == total.toInt()) {
      return total.toInt();
    }
    return total;
  },
  'round': (val, args) {
    if (val == null) return 0;
    final number = val is num ? val.toDouble() : double.tryParse(val.toString());
    if (number == null) return val;
    final decimals = args.isNotEmpty && args[0] is num
        ? (args[0] as num).toInt()
        : 0;
    if (decimals <= 0) {
      return number.round();
    }
    return double.parse(number.toStringAsFixed(decimals));
  },
  'number_format': (val, args) {
    if (val == null) return '';
    final numVal = val is num ? val : num.tryParse(val.toString());
    if (numVal == null) return val.toString();
    final decimals = args.isNotEmpty && args[0] is num
        ? (args[0] as num).toInt()
        : null;

    String str;
    if (decimals != null) {
      str = numVal.toStringAsFixed(decimals);
    } else {
      str = numVal.toString();
    }
    final parts = str.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    if (parts.length > 1) {
      return '$intPart.${parts[1]}';
    }
    return intPart;
  },

  // Duration & JSON Filters
  'duration': (val, args) {
    if (val == null) return '';
    final numVal = val is num ? val.toDouble() : double.tryParse(val.toString());
    if (numVal == null) return val.toString();
    final unit = args.isNotEmpty ? args[0]?.toString().toLowerCase() : 's';
    final totalSeconds = (unit == 'ms' ? numVal / 1000 : numVal).round();
    if (totalSeconds < 60) return '${totalSeconds}s';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m${seconds > 0 ? ' ${seconds}s' : ''}';
    }
    return '${minutes}m${seconds > 0 ? ' ${seconds}s' : ''}';
  },
  'parse_json': (val, args) {
    if (val == null) return null;
    try {
      return jsonDecode(val.toString());
    } catch (_) {
      return null;
    }
  },

  // Math Arithmetic Calculator
  'calc': (val, args) {
    if (val == null || args.isEmpty) return val;
    final numVal = val is num ? val.toDouble() : double.tryParse(val.toString());
    if (numVal == null) return val;

    final operation = args[0]?.toString().trim() ?? '';
    if (operation.isEmpty) return numVal;

    final operator = operation.startsWith('**')
        ? '**'
        : operation.substring(0, 1);
    final valueStr = operation.substring(operator.length).trim();
    final operand = double.tryParse(valueStr);
    if (operand == null) return numVal;

    double result;
    switch (operator) {
      case '+':
        result = numVal + operand;
        break;
      case '-':
        result = numVal - operand;
        break;
      case '*':
        result = numVal * operand;
        break;
      case '/':
        result = operand != 0 ? numVal / operand : 0;
        break;
      case '**':
      case '^':
        result = math.pow(numVal, operand).toDouble();
        break;
      default:
        return numVal;
    }

    if (result == result.toInt()) {
      return result.toInt();
    }
    return double.parse(result.toStringAsFixed(10));
  },

  // Nth item selection / step filter
  'nth': (val, args) {
    if (val is! Iterable || args.isEmpty) return val;
    final list = val.toList();
    final param = args[0]?.toString().trim() ?? '';
    if (param.isEmpty) return list;

    // Basis pattern: 1,2:5
    if (param.contains(':')) {
      final parts = param.split(':');
      final positions = parts[0]
          .split(',')
          .map((n) => int.tryParse(n.trim()) ?? 0)
          .where((n) => n > 0)
          .toSet();
      final basis = int.tryParse(parts[1].trim()) ?? 1;
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

  // Object keys, values, array extraction
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

  // Template string interpolator
  'template': (val, args) {
    if (val == null || args.isEmpty) return val?.toString() ?? '';
    final tpl = args[0]?.toString() ?? '';
    final list = val is Iterable ? val.toList() : [val];

    return list.map((item) {
      var rendered = tpl;
      if (item is Map) {
        for (final entry in item.entries) {
          rendered = rendered.replaceAll(
            '\${${entry.key}}',
            entry.value?.toString() ?? '',
          );
        }
      } else {
        rendered = rendered.replaceAll('\${str}', item.toString());
      }
      return rendered.replaceAll(r'\n', '\n');
    }).join('\n\n');
  },

  // String uncamel & unescape
  'uncamel': (val, args) {
    final str = val?.toString() ?? '';
    if (str.isEmpty) return '';
    final spaced = str.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    return spaced
        .replaceAllMapped(
          RegExp(r'([A-Z])([A-Z][a-z])'),
          (m) => '${m.group(1)} ${m.group(2)}',
        )
        .toLowerCase();
  },
  'unescape': (val, args) {
    final str = val?.toString() ?? '';
    return str.replaceAll(r'\"', '"').replaceAll(r'\n', '\n');
  },

  // HTML Attributes & Tag replacement
  'strip_attr': (val, args) {
    final html = val?.toString() ?? '';
    final keepList = args.map((e) => e?.toString().toLowerCase()).toSet();
    return html.replaceAllMapped(RegExp(r'<(\w+)\s+(?:[^>]*?)>'), (match) {
      final tag = match.group(1)!;
      if (keepList.isEmpty) return '<$tag>';
      final matchedText = match.group(0)!;
      final keptAttrs = <String>[];
      for (final attr in keepList) {
        if (attr == null || attr.isEmpty) continue;
        final reg = RegExp(
          '\\s$attr\\s*=\\s*("[^"]*"|\'[^\']*\')',
          caseSensitive: false,
        );
        final m = reg.firstMatch(matchedText);
        if (m != null) keptAttrs.add(m.group(0)!.trim());
      }
      return keptAttrs.isNotEmpty ? '<$tag ${keptAttrs.join(' ')}>' : '<$tag>';
    });
  },
  'remove_attr': (val, args) {
    final html = val?.toString() ?? '';
    final removeList = args.map((e) => e?.toString().toLowerCase()).toSet();
    if (removeList.isEmpty) return html;
    return html.replaceAllMapped(RegExp(r'<(\w+)\s+([^>]*?)>'), (match) {
      final tag = match.group(1)!;
      final attrsStr = match.group(2)!;
      final attrRegex = RegExp(
        r"""([a-zA-Z0-9_:-]+)(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+))?""",
      );
      final kept = <String>[];
      for (final m in attrRegex.allMatches(attrsStr)) {
        final attrName = m.group(1)!.toLowerCase();
        if (!removeList.contains(attrName)) {
          kept.add(m.group(0)!);
        }
      }
      return kept.isNotEmpty ? '<$tag ${kept.join(' ')}>' : '<$tag>';
    });
  },
  'replace_tags': (val, args) {
    final html = val?.toString() ?? '';
    if (args.isEmpty) return html;
    final sourceTag = args[0]?.toString() ?? '';
    final targetTag = args.length > 1 ? args[1]?.toString() ?? '' : '';
    if (sourceTag.isEmpty) return html;
    final openRegex = RegExp('<$sourceTag(\\s+[^>]*?)?>', caseSensitive: false);
    final closeRegex = RegExp('</$sourceTag>', caseSensitive: false);
    return html
        .replaceAllMapped(
          openRegex,
          (m) =>
              targetTag.isNotEmpty ? '<$targetTag${m.group(1) ?? ''}>' : '',
        )
        .replaceAll(closeRegex, targetTag.isNotEmpty ? '</$targetTag>' : '');
  },
};
