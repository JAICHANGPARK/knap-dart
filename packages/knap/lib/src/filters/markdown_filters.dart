import 'dart:math' as math;
import 'filter.dart';

Object? _formatWikiReference(
  Object? val,
  List<Object?> args,
  String prefix,
) {
  if (val == null) return '';
  final alias =
      (args.isNotEmpty && args[0] != null && args[0].toString().isNotEmpty)
      ? args[0].toString()
      : '';

  List<String> processMap(Map map) {
    final res = <String>[];
    for (final entry in map.entries) {
      if (entry.value is Map) {
        res.addAll(processMap(entry.value as Map));
      } else {
        res.add('$prefix[[${entry.key}|${entry.value}]]');
      }
    }
    return res;
  }

  if (val is Map) {
    return processMap(val);
  }
  if (val is Iterable) {
    final res = <String>[];
    for (final item in val) {
      if (item is Map) {
        res.addAll(processMap(item));
      } else if (item != null && item.toString().isNotEmpty) {
        res.add(
          alias.isNotEmpty
              ? '$prefix[[$item|$alias]]'
              : '$prefix[[$item]]',
        );
      }
    }
    return res;
  }

  final target = val.toString().trim();
  if (target.isEmpty) return '';
  return alias.isNotEmpty
      ? '$prefix[[$target|$alias]]'
      : '$prefix[[$target]]';
}

String _escapeTableCell(Object? value) =>
    (value?.toString() ?? '').replaceAll('|', r'\|');

int _cellWidth(String cell) => cell.runes.length;

String _padCell(String cell, int width) =>
    '$cell${' ' * math.max(0, width - _cellWidth(cell))}';

String _renderMarkdownTable(
  List<String> headers,
  List<List<String>> rows, {
  required bool pretty,
}) {
  if (headers.isEmpty) return '';
  final colCount = headers.length;
  final normHeaders = headers.map(_escapeTableCell).toList();
  final normRows = rows.map((row) {
    final padded = <String>[];
    for (var i = 0; i < colCount; i++) {
      padded.add(i < row.length ? _escapeTableCell(row[i]) : '');
    }
    return padded;
  }).toList();

  if (!pretty) {
    final lines = <String>[
      '| ${normHeaders.join(' | ')} |',
      '| ${normHeaders.map((_) => '---').join(' | ')} |',
      ...normRows.map((r) => '| ${r.join(' | ')} |'),
    ];
    return lines.join('\n');
  }

  final widths = List<int>.generate(colCount, (col) {
    var w = math.max(3, _cellWidth(normHeaders[col]));
    for (final row in normRows) {
      w = math.max(w, _cellWidth(row[col]));
    }
    return w;
  });

  String formatRow(List<String> row) {
    final cells = List<String>.generate(
      colCount,
      (col) => _padCell(row[col], widths[col]),
    );
    return '| ${cells.join(' | ')} |';
  }

  final lines = <String>[
    formatRow(normHeaders),
    '| ${widths.map((w) => '-' * w).join(' | ')} |',
    ...normRows.map(formatRow),
  ];
  return lines.join('\n');
}

String _formatTableData(
  Object? val,
  List<Object?> args, {
  required bool pretty,
}) {
  if (val == null) return '';
  final customHeaders = <String>[];
  if (args.isNotEmpty) {
    if (args[0] is Iterable) {
      customHeaders.addAll((args[0] as Iterable).map((e) => e.toString()));
    } else {
      customHeaders.addAll(args.map((e) => e?.toString() ?? ''));
    }
  }

  if (val is Map) {
    if (val.isEmpty) return '';
    final entries = val.entries.toList();
    final first = entries.first;
    final headers = [first.key.toString(), first.value?.toString() ?? ''];
    final rows = entries
        .skip(1)
        .map((e) => [e.key.toString(), e.value?.toString() ?? ''])
        .toList();
    return _renderMarkdownTable(headers, rows, pretty: pretty);
  }

  if (val is Iterable) {
    final list = val.toList();
    if (list.isEmpty) return '';

    if (list.first is Map) {
      final headers = <String>[...customHeaders];
      if (headers.isEmpty) {
        for (final item in list) {
          if (item is Map) {
            for (final key in item.keys) {
              final kStr = key.toString();
              if (!headers.contains(kStr)) headers.add(kStr);
            }
          }
        }
      }
      final rows = list.whereType<Map>().map((item) {
        return headers.map((h) => item[h]?.toString() ?? '').toList();
      }).toList();
      return _renderMarkdownTable(headers, rows, pretty: pretty);
    }

    if (list.first is Iterable) {
      final matrix = list
          .whereType<Iterable>()
          .map((r) => r.map((c) => c?.toString() ?? '').toList())
          .toList();
      var maxCols = 0;
      for (final r in matrix) {
        maxCols = math.max(maxCols, r.length);
      }
      final headers = customHeaders.isNotEmpty
          ? List<String>.generate(
              maxCols,
              (i) => i < customHeaders.length ? customHeaders[i] : '',
            )
          : List<String>.filled(maxCols, '');
      return _renderMarkdownTable(headers, matrix, pretty: pretty);
    }

    if (customHeaders.isNotEmpty) {
      final rows = <List<String>>[];
      for (var i = 0; i < list.length; i += customHeaders.length) {
        final chunk = list
            .skip(i)
            .take(customHeaders.length)
            .map((e) => e?.toString() ?? '')
            .toList();
        rows.add(chunk);
      }
      return _renderMarkdownTable(customHeaders, rows, pretty: pretty);
    }
    return '';
  }

  return '';
}

String _formatListItems(
  Iterable items,
  String mode, {
  int depth = 0,
}) {
  final list = items.toList();
  if (list.isEmpty) return '';
  final indent = '\t' * depth;
  final lines = <String>[];
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    if (item is Iterable) {
      lines.add(_formatListItems(item, mode, depth: depth + 1));
      continue;
    }
    final prefix = switch (mode) {
      'numbered' => '${i + 1}. ',
      'task' => '- [ ] ',
      'numbered-task' => '${i + 1}. [ ] ',
      _ => '$mode ',
    };
    lines.add('$indent$prefix${item?.toString() ?? ''}');
  }
  return lines.join('\n');
}

int _longestBacktickRun(String str) {
  var maxRun = 0;
  for (final match in RegExp(r'`+').allMatches(str)) {
    maxRun = math.max(maxRun, match.group(0)!.length);
  }
  return maxRun;
}

/// The built-in library of Markdown, HTML, and Obsidian syntax generation filters.
final Map<String, KnapFilter> markdownFilters = {
  // Wikilink: [[Target]] or [[Target|Alias]]
  'wikilink': (val, args) => _formatWikiReference(val, args, ''),

  // Embed: ![[Target]] or ![[Target|Alias]]
  'embed': (val, args) => _formatWikiReference(val, args, '!'),

  // Standard Markdown Link: [text](url)
  'link': (val, args) {
    final url = val?.toString().trim() ?? '';
    if (url.isEmpty) return '';
    final text = args.isNotEmpty ? args[0]?.toString() ?? url : url;
    return '[$text]($url)';
  },

  // Bullet / numbered / task list:
  'list': (val, args) {
    if (val == null) return '';
    final rawArg = args.isNotEmpty ? args[0]?.toString() ?? '-' : '-';
    final lowerArg = rawArg.toLowerCase();
    final mode =
        (lowerArg == 'numbered' ||
            lowerArg == 'task' ||
            lowerArg == 'numbered-task')
        ? lowerArg
        : rawArg;
    if (val is Iterable) {
      return _formatListItems(val, mode);
    }
    final str = val.toString();
    if (str.isEmpty) return '';
    return _formatListItems([str], mode);
  },

  // Task list:
  // - [ ] item 1
  // - [x] item 2
  'task_list': (val, args) {
    if (val == null) return '';
    if (val is Iterable) {
      if (val.isEmpty) return '';
      return val.map((item) {
        if (item is Map) {
          final isCompleted =
              item['completed'] == true ||
              item['done'] == true ||
              item['checked'] == true;
          final title = item['title'] ?? item['name'] ?? item['text'] ?? '';
          return '- [${isCompleted ? 'x' : ' '}] $title';
        }
        return '- [ ] ${item?.toString() ?? ''}';
      }).join('\n');
    }
    return '- [ ] ${val.toString()}';
  },

  // Blockquote: prepend > to each line
  'quote': (val, args) {
    final str = val?.toString() ?? '';
    if (str.isEmpty) return '';
    return str
        .split('\n')
        .map((line) => line.isEmpty ? '>' : '> $line')
        .join('\n');
  },

  // Obsidian Callout:
  // > [!NOTE] Optional Title
  // > Body text
  'callout': (val, args) {
    final type = args.isNotEmpty
        ? args[0]?.toString().toUpperCase() ?? 'NOTE'
        : 'NOTE';
    final title = args.length > 1 ? args[1]?.toString() : null;
    String foldState = '';
    if (args.length > 2 && args[2] != null) {
      final foldStr = args[2].toString().toLowerCase();
      if (foldStr == 'true' || foldStr == '-') {
        foldState = '-';
      } else if (foldStr == 'false' || foldStr == '+') {
        foldState = '+';
      }
    }
    final header = title != null && title.isNotEmpty
        ? '> [!$type]$foldState $title'
        : '> [!$type]$foldState';

    final body = val?.toString() ?? '';
    if (body.isEmpty) return header;

    final bodyLines = body
        .split('\n')
        .map((line) => line.isEmpty ? '>' : '> $line')
        .join('\n');

    return '$header\n$bodyLines';
  },

  // Table filter: converts list of maps/lists to markdown table
  'table': (val, args) => _formatTableData(val, args, pretty: false),

  // Pretty Table filter: converts list of maps/lists to column-padded markdown table
  'table_pretty': (val, args) => _formatTableData(val, args, pretty: true),

  // Inline formatting
  'bold': (val, args) {
    if (val == null) return '';
    final marker = (args.isNotEmpty && args[0]?.toString() == '_')
        ? '__'
        : '**';
    if (val is Iterable) {
      return val
          .map((e) => e == null || e.toString().isEmpty ? '' : '$marker$e$marker')
          .toList();
    }
    final str = val.toString();
    return str.isEmpty ? '' : '$marker$str$marker';
  },
  'italic': (val, args) {
    if (val == null) return '';
    final marker = (args.isNotEmpty && args[0]?.toString() == '_') ? '_' : '*';
    if (val is Iterable) {
      return val
          .map((e) => e == null || e.toString().isEmpty ? '' : '$marker$e$marker')
          .toList();
    }
    final str = val.toString();
    return str.isEmpty ? '' : '$marker$str$marker';
  },
  'strikethrough': (val, args) {
    final str = val?.toString() ?? '';
    return str.isEmpty ? '' : '~~$str~~';
  },
  'inline_code': (val, args) {
    final str = val?.toString() ?? '';
    if (str.isEmpty) return '';
    final delim = '`' * math.max(1, _longestBacktickRun(str) + 1);
    return '$delim$str$delim';
  },
  'codeblock': (val, args) {
    final lang = args.isNotEmpty ? args[0]?.toString() ?? '' : '';
    final str = val?.toString() ?? '';
    final fence = '`' * math.max(3, _longestBacktickRun(str) + 1);
    return '$fence$lang\n$str\n$fence';
  },
  'tag': (val, args) {
    final str = val?.toString().trim() ?? '';
    if (str.isEmpty) return '';
    final cleanTag = str.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\/]'), '');
    return cleanTag.startsWith('#') ? cleanTag : '#$cleanTag';
  },
  'escape_md': (val, args) {
    final str = val?.toString() ?? '';
    // Escapes markdown characters: \ ` * _ { } [ ] ( ) # + - . ! |
    return str.replaceAllMapped(
      RegExp(r'([\\`*_\[\]()#+\-.!|])'),
      (match) => '\\${match.group(1)}',
    );
  },
  'blockquote': (val, args) => markdownFilters['quote']!(val, args),
  'strip_md': (val, args) {
    var str = val?.toString() ?? '';
    if (str.isEmpty) return '';
    // Strip fenced code blocks
    str = str.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    // Strip inline code
    str = str.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!);
    // Images ![alt](url) -> alt
    str = str.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
      (m) => m.group(1)!,
    );
    // Links [text](url) -> text
    str = str.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m.group(1)!,
    );
    // Wikilinks [[target|alias]] -> alias or target
    str = str.replaceAllMapped(
      RegExp(r'\[\[(?:[^|\]]+\|)?([^\]]+)\]\]'),
      (m) => m.group(1)!,
    );
    // Headers (# Header)
    str = str.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // Blockquotes (> text)
    str = str.replaceAll(RegExp(r'^>\s?', multiLine: true), '');
    // Lists (- / * / 1. )
    str = str.replaceAll(
      RegExp(r'^\s*([-*+]|\d+\.)\s+', multiLine: true),
      '',
    );
    // Bold / italic (***, **, *, ___, __, _)
    str = str.replaceAllMapped(
      RegExp(r'(\*{1,3}|_{1,3})([^*_]+)\1'),
      (m) => m.group(2)!,
    );
    // Strikethrough ~~text~~
    str = str.replaceAllMapped(RegExp(r'~~([^~]+)~~'), (m) => m.group(1)!);
    return str.trim();
  },
  'stripmd': (val, args) => markdownFilters['strip_md']!(val, args),
  'image': (val, args) {
    final url = val?.toString().trim() ?? '';
    if (url.isEmpty) return '';
    final alt = args.isNotEmpty ? args[0]?.toString() ?? '' : '';
    return '![$alt]($url)';
  },
  'footnote': (val, args) {
    if (val == null) return '';
    if (val is Iterable) {
      final list = val.toList();
      return List<String>.generate(
        list.length,
        (i) => '[^${i + 1}]: ${list[i]}',
      ).join('\n\n');
    }
    if (val is Map) {
      return val.entries.map((e) {
        final footnoteId = e.key
            .toString()
            .replaceAllMapped(
              RegExp(r'([a-z])([A-Z])'),
              (m) => '${m.group(1)}-${m.group(2)}',
            )
            .replaceAll(RegExp(r'[\s_]+'), '-')
            .toLowerCase();
        return '[^$footnoteId]: ${e.value}';
      }).join('\n\n');
    }
    final id = val.toString().trim();
    if (id.isEmpty) return '';
    return '[^$id]';
  },
  'fragment_link': (val, args) {
    final str = val?.toString().trim() ?? '';
    if (str.isEmpty) return '';
    final slug = str
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s_-]'), '')
        .replaceAll(RegExp(r'[\s_]+'), '-');
    return '#$slug';
  },

  // Markdown Headings
  'h1': (val, args) => '# ${val?.toString() ?? ''}',
  'h2': (val, args) => '## ${val?.toString() ?? ''}',
  'h3': (val, args) => '### ${val?.toString() ?? ''}',
  'h4': (val, args) => '#### ${val?.toString() ?? ''}',
  'h5': (val, args) => '##### ${val?.toString() ?? ''}',
  'h6': (val, args) => '###### ${val?.toString() ?? ''}',

  // Markdown Formatting & Inline
  'strike': (val, args) => markdownFilters['strikethrough']!(val, args),
  'highlight': (val, args) {
    final str = val?.toString() ?? '';
    if (str.isEmpty) return '';
    final color = args.isNotEmpty ? args[0]?.toString().toLowerCase() : null;
    final marker = switch (color) {
      'red' => '🔴',
      'orange' => '🟠',
      'yellow' => '🟡',
      'green' => '🟢',
      'blue' => '🔵',
      'purple' => '🟣',
      _ => '',
    };
    return '==$marker$str==';
  },
  'hr': (val, args) {
    final str = val?.toString() ?? '';
    final pos = args.isNotEmpty ? args[0]?.toString().toLowerCase() : 'after';
    if (pos == 'before') return '---\n\n$str';
    if (pos == 'both') return '---\n\n$str\n\n---';
    return str.isEmpty ? '---' : '$str\n\n---';
  },
  'code': (val, args) {
    final str = val?.toString() ?? '';
    final lang = args.isNotEmpty ? args[0]?.toString() : null;
    if (lang != null || str.contains('\n')) {
      final fence = '`' * math.max(3, _longestBacktickRun(str) + 1);
      return '$fence${lang ?? ''}\n$str\n$fence';
    }
    final delim = '`' * math.max(1, _longestBacktickRun(str) + 1);
    return '$delim$str$delim';
  },
  'code_block': (val, args) {
    final str = val?.toString() ?? '';
    final lang = args.isNotEmpty ? args[0]?.toString() ?? '' : '';
    final fence = '`' * math.max(3, _longestBacktickRun(str) + 1);
    return '$fence$lang\n$str\n$fence';
  },
  'math': (val, args) {
    final str = val?.toString() ?? '';
    if (str.contains('\n')) return '\$\$\n$str\n\$\$';
    return '\$$str\$';
  },
  'math_block': (val, args) {
    final str = val?.toString() ?? '';
    return '\$\$\n$str\n\$\$';
  },
  'comment': (val, args) {
    final str = val?.toString() ?? '';
    if (str.contains('\n')) return '%%\n$str\n%%';
    return '%%$str%%';
  },
};
