import 'dart:convert';
import 'filter.dart';

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
  'json': (val, args) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(val);
    } catch (_) {
      return val?.toString() ?? '';
    }
  },
};
