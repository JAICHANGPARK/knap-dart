import 'filter.dart';

final Map<String, KnapFilter> markdownFilters = {
  // Wikilink: [[Target]] or [[Target|Alias]]
  'wikilink': (val, args) {
    final target = val?.toString().trim() ?? '';
    if (target.isEmpty) return '';
    if (args.isNotEmpty && args[0] != null && args[0].toString().isNotEmpty) {
      final alias = args[0].toString();
      return '[[$target|$alias]]';
    }
    return '[[$target]]';
  },

  // Standard Markdown Link: [text](url)
  'link': (val, args) {
    final url = val?.toString().trim() ?? '';
    if (url.isEmpty) return '';
    final text = args.isNotEmpty ? args[0]?.toString() ?? url : url;
    return '[$text]($url)';
  },

  // Bullet list:
  // - item 1
  // - item 2
  'list': (val, args) {
    if (val == null) return '';
    final marker = args.isNotEmpty ? args[0]?.toString() ?? '-' : '-';
    if (val is Iterable) {
      if (val.isEmpty) return '';
      return val.map((e) => '$marker ${e?.toString() ?? ''}').join('\n');
    }
    return '$marker ${val.toString()}';
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
          final isCompleted = item['completed'] == true ||
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
    final type = args.isNotEmpty ? args[0]?.toString().toUpperCase() ?? 'NOTE' : 'NOTE';
    final title = args.length > 1 ? args[1]?.toString() : null;
    final header = title != null && title.isNotEmpty ? '> [!$type] $title' : '> [!$type]';

    final body = val?.toString() ?? '';
    if (body.isEmpty) return header;

    final bodyLines = body
        .split('\n')
        .map((line) => line.isEmpty ? '>' : '> $line')
        .join('\n');

    return '$header\n$bodyLines';
  },

  // Table filter: converts list of maps to markdown table
  'table': (val, args) {
    if (val is! Iterable || val.isEmpty) return '';
    final list = val.toList();
    if (list.first is! Map) return '';

    // Collect all headers
    final headers = <String>[];
    if (args.isNotEmpty && args[0] is List) {
      headers.addAll((args[0] as List).map((e) => e.toString()));
    } else {
      for (final item in list) {
        if (item is Map) {
          for (final key in item.keys) {
            final keyStr = key.toString();
            if (!headers.contains(keyStr)) {
              headers.add(keyStr);
            }
          }
        }
      }
    }

    if (headers.isEmpty) return '';

    final buffer = StringBuffer();
    // Header row
    buffer.writeln('| ${headers.join(' | ')} |');
    // Separator row
    buffer.writeln('| ${headers.map((_) => '---').join(' | ')} |');

    // Data rows
    for (final item in list) {
      if (item is Map) {
        final row = headers.map((h) => item[h]?.toString().replaceAll('|', '\\|') ?? '').join(' | ');
        buffer.writeln('| $row |');
      }
    }

    return buffer.toString().trimRight();
  },

  // Inline formatting
  'bold': (val, args) {
    final str = val?.toString() ?? '';
    return str.isEmpty ? '' : '**$str**';
  },
  'italic': (val, args) {
    final str = val?.toString() ?? '';
    return str.isEmpty ? '' : '*$str*';
  },
  'strikethrough': (val, args) {
    final str = val?.toString() ?? '';
    return str.isEmpty ? '' : '~~$str~~';
  },
  'inline_code': (val, args) {
    final str = val?.toString() ?? '';
    return str.isEmpty ? '' : '`$str`';
  },
  'codeblock': (val, args) {
    final lang = args.isNotEmpty ? args[0]?.toString() ?? '' : '';
    final str = val?.toString() ?? '';
    return '```$lang\n$str\n```';
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
    str = str.replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), (m) => m.group(1)!);
    // Links [text](url) -> text
    str = str.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!);
    // Wikilinks [[target|alias]] -> alias or target
    str = str.replaceAllMapped(RegExp(r'\[\[(?:[^|\]]+\|)?([^\]]+)\]\]'), (m) => m.group(1)!);
    // Headers (# Header)
    str = str.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // Blockquotes (> text)
    str = str.replaceAll(RegExp(r'^>\s?', multiLine: true), '');
    // Lists (- / * / 1. )
    str = str.replaceAll(RegExp(r'^\s*([-*+]|\d+\.)\s+', multiLine: true), '');
    // Bold / italic (***, **, *, ___, __, _)
    str = str.replaceAllMapped(RegExp(r'(\*{1,3}|_{1,3})([^*_]+)\1'), (m) => m.group(2)!);
    // Strikethrough ~~text~~
    str = str.replaceAllMapped(RegExp(r'~~([^~]+)~~'), (m) => m.group(1)!);
    return str.trim();
  },
  'image': (val, args) {
    final url = val?.toString().trim() ?? '';
    if (url.isEmpty) return '';
    final alt = args.isNotEmpty ? args[0]?.toString() ?? '' : '';
    return '![$alt]($url)';
  },
  'footnote': (val, args) {
    final id = val?.toString().trim() ?? '';
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
      return '```${lang ?? ''}\n$str\n```';
    }
    return '`$str`';
  },
  'code_block': (val, args) {
    final str = val?.toString() ?? '';
    final lang = args.isNotEmpty ? args[0]?.toString() ?? '' : '';
    return '```$lang\n$str\n```';
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
