import 'dart:convert';
import 'filter.dart';

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
        words.skip(1).map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join('');
  },
  'kebab': (val, args) {
    final words = _splitWords(val?.toString() ?? '');
    return words.map((w) => w.toLowerCase()).join('-');
  },
  'pascal': (val, args) {
    final words = _splitWords(val?.toString() ?? '');
    return words.map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join('');
  },

  'replace': (val, args) {
    final str = val?.toString() ?? '';
    if (args.isEmpty) return str;
    final from = args[0]?.toString() ?? '';
    final to = args.length > 1 ? (args[1]?.toString() ?? '') : '';
    return str.replaceAll(from, to);
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
    final maxLen = args.isNotEmpty && args[0] is num ? (args[0] as num).toInt() : 50;
    final suffix = args.length > 1 ? args[1]?.toString() ?? '...' : '...';
    if (str.length <= maxLen) return str;
    return '${str.substring(0, maxLen)}$suffix';
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
    if (val is List) {
      final copy = List<Object?>.from(val);
      copy.sort((a, b) => (a?.toString() ?? '').compareTo(b?.toString() ?? ''));
      return copy;
    }
    if (val is Iterable) {
      final copy = val.toList();
      copy.sort((a, b) => (a?.toString() ?? '').compareTo(b?.toString() ?? ''));
      return copy;
    }
    return val;
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
    final start = args.isNotEmpty && args[0] is num ? (args[0] as num).toInt() : 0;
    final end = args.length > 1 && args[1] is num ? (args[1] as num).toInt() : null;

    if (val is List) {
      final effectiveStart = start.clamp(0, val.length);
      final effectiveEnd = end != null ? end.clamp(effectiveStart, val.length) : val.length;
      return val.sublist(effectiveStart, effectiveEnd);
    }
    if (val is String) {
      final effectiveStart = start.clamp(0, val.length);
      final effectiveEnd = end != null ? end.clamp(effectiveStart, val.length) : val.length;
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
    final str = val.toString();
    if (str.isEmpty) return "''";
    if (RegExp(r'[:#\[\]{}&*!|>"%@`]|\n').hasMatch(str) ||
        str.startsWith(' ') ||
        str.endsWith(' ')) {
      return jsonEncode(str);
    }
    return str;
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
    final format = args.isNotEmpty ? args[0]?.toString() ?? 'YYYY-MM-DD' : 'YYYY-MM-DD';
    return _formatDate(dt, format);
  },
  'date_modify': (val, args) {
    final dt = _parseDateTime(val);
    if (dt == null || args.isEmpty) return val?.toString() ?? '';

    final modifier = args[0]?.toString().trim() ?? '';
    final match = RegExp(r'^([+-]?\d+)\s*(year|month|week|day|hour|minute|second)s?$', caseSensitive: false)
        .firstMatch(modifier);

    if (match == null) return _formatDate(dt, 'YYYY-MM-DD');

    final amount = int.tryParse(match.group(1)!) ?? 0;
    final unit = match.group(2)!.toLowerCase();

    DateTime modified;
    switch (unit) {
      case 'year':
        modified = DateTime(dt.year + amount, dt.month, dt.day, dt.hour, dt.minute, dt.second);
        break;
      case 'month':
        modified = DateTime(dt.year, dt.month + amount, dt.day, dt.hour, dt.minute, dt.second);
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

    final format = args.length > 1 ? args[1]?.toString() ?? 'YYYY-MM-DD' : 'YYYY-MM-DD';
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
    final width = args.isNotEmpty && args[0] is num ? (args[0] as num).toInt() : 2;
    final indentStr = ' ' * width;
    return str.split('\n').map((line) => line.isEmpty ? line : '$indentStr$line').join('\n');
  },
  'encode_uri': (val, args) => Uri.encodeComponent(val?.toString() ?? ''),
  'decode_uri': (val, args) => Uri.decodeComponent(val?.toString() ?? ''),
  'safe_name': (val, args) {
    final str = val?.toString() ?? '';
    final replacement = args.isNotEmpty ? args[0]?.toString() ?? '' : '';
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

  // Additional Collection Filters
  'where': (val, args) {
    if (val is! Iterable || args.isEmpty) return val;
    final key = args[0]?.toString() ?? '';
    final hasExpected = args.length > 1;
    final expected = hasExpected ? args[1] : null;

    return val.where((item) {
      if (item is Map) {
        final itemVal = item[key];
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
    return val.map((item) {
      if (item is Map) {
        return item[key];
      }
      return null;
    }).toList();
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
    final decimals = args.isNotEmpty && args[0] is num ? (args[0] as num).toInt() : 0;
    if (decimals <= 0) {
      return number.round();
    }
    return double.parse(number.toStringAsFixed(decimals));
  },
  'number_format': (val, args) {
    if (val == null) return '';
    final numVal = val is num ? val : num.tryParse(val.toString());
    if (numVal == null) return val.toString();
    final decimals = args.isNotEmpty && args[0] is num ? (args[0] as num).toInt() : null;

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
};
