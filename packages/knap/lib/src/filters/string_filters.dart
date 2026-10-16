import 'dart:math' as math;
import '../runtime/context.dart';
import 'filter.dart';

List<String> _splitWords(String str) {
  if (str.isEmpty) return [];
  final parts = <String>[];
  final regex = RegExp(r'[A-Z]?[a-z0-9]+|[A-Z]+(?![a-z0-9])');
  for (final match in regex.allMatches(str)) {
    parts.add(match.group(0)!);
  }
  return parts;
}

/// Standard string manipulation, casing, and sanitation filters.
final Map<String, KnapFilter> stringFilters = {
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
      try {
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
      } catch (_) {
        reportFilterWarning(
          'Invalid regex pattern: $from',
          'replace',
        );
        return val;
      }
    }
    return str;
  },
  'truncate': (val, args) {
    final str = val?.toString() ?? '';
    final maxLen = args.isNotEmpty
        ? (args[0] is num
              ? (args[0] as num).toInt()
              : int.tryParse(args[0]?.toString() ?? '') ?? 50)
        : 50;
    final suffix = args.length > 1 ? args[1]?.toString() ?? '…' : '…';
    if (maxLen <= 0) return '';
    if (str.length <= maxLen) return str;
    final contentLimit = math.max(0, maxLen - suffix.length);
    return '${str.substring(0, contentLimit)}$suffix';
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
    var str = val?.toString() ?? '';
    if (str.isEmpty) return '';
    final keepTags = <String>{};
    if (args.isNotEmpty) {
      if (args[0] is Iterable) {
        keepTags.addAll((args[0] as Iterable).map((e) => e.toString().toLowerCase().trim()));
      } else {
        keepTags.addAll(args.map((e) => e?.toString().toLowerCase().trim() ?? '').where((s) => s.isNotEmpty));
      }
    }
    str = str.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    if (keepTags.isEmpty) {
      str = str.replaceAll(RegExp(r'<[^>]*>'), '');
    } else {
      str = str.replaceAllMapped(RegExp(r'</?([a-zA-Z0-9]+)(\s+[^>]*)?>'), (m) {
        final tag = m.group(1)!.toLowerCase();
        if (keepTags.contains(tag)) return m.group(0)!;
        return '';
      });
    }
    return str
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .trim();
  },
  'remove_html': (val, args) {
    var str = val?.toString() ?? '';
    if (str.isEmpty) return str;
    if (args.isEmpty) {
      return stringFilters['strip_tags']!(val, args);
    }
    final tags = (args[0] is Iterable)
        ? (args[0] as Iterable).map((e) => e.toString().toLowerCase().trim()).toList()
        : args.map((e) => e?.toString().toLowerCase().trim() ?? '').where((s) => s.isNotEmpty).toList();
    for (final t in tags) {
      str = str.replaceAll(RegExp('<$t(\\s+[^>]*)?>[\\s\\S]*?<\\/$t>', caseSensitive: false), '');
      str = str.replaceAll(RegExp('<$t(\\s+[^>]*)?\\/?>', caseSensitive: false), '');
    }
    return str;
  },
  'remove_tags': (val, args) {
    var str = val?.toString() ?? '';
    if (str.isEmpty) return str;
    if (args.isEmpty) {
      return stringFilters['strip_tags']!(val, args);
    }
    final tags = (args[0] is Iterable)
        ? (args[0] as Iterable).map((e) => e.toString().toLowerCase().trim()).toList()
        : args.map((e) => e?.toString().toLowerCase().trim() ?? '').where((s) => s.isNotEmpty).toList();
    for (final t in tags) {
      str = str.replaceAll(RegExp('<\\/?$t(\\s+[^>]*)?>', caseSensitive: false), '');
    }
    return str;
  },
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
