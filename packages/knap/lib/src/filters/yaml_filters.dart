import 'dart:convert';
import 'filter.dart';

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

/// YAML and JSON serialization and parsing filters.
///
/// Provides structured object encoding and decoding including `yaml`,
/// `yaml_property`, `json`, `parse_json`, `template`, and `object`.
///
/// ```dart
/// final yamlText = yamlFilters['yaml']!({'title': 'Note'}, const []);
/// // 'title: Note'
/// ```
final Map<String, KnapFilter> yamlFilters = {
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
    return str.replaceAllMapped(RegExp(r'(?<!\n)\n(?!\n)'), (m) => '  \n');
  },
  'json': (val, args) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(val);
    } catch (_) {
      return val?.toString() ?? '';
    }
  },
  'parse_json': (val, args) {
    if (val == null) return null;
    try {
      return jsonDecode(val.toString());
    } catch (_) {
      return null;
    }
  },
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
};
