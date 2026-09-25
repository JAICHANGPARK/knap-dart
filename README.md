# Knap for Dart & Flutter

A simple, fast, and safe template language for turning data into Markdown using variables, filters, and logic.
Inspired by [Obsidian Knap](https://github.com/obsidianmd/knap).

## Packages

| Package | Description | Directory |
|---|---|---|
| [`knap`](packages/knap) | Core pure Dart template engine + CLI | `packages/knap` |
| [`flutter_knap`](packages/flutter_knap) | Flutter widgets & real-time markdown preview | `packages/flutter_knap` |

---

## Features

- **Safe Execution**: AST-based interpreter with zero `eval` or arbitrary code execution.
- **Markdown-first**: Built-in filters for `wikilink`, `list`, `task_list`, `table`, `callout`, `quote`, `tag`, and `escape_md`.
- **Whitespace Trimming**: Liquid/Jinja-compatible `{{- -}}` and `{%- -%}` whitespace control.
- **Rich Logic**: `if / elif / else` branching, `for ... in ...` loops with loop variables (`loop.index`, `loop.first`, `loop.last`, etc.).
- **Async Filter Support**: Both synchronous (`render()`) and asynchronous (`renderAsync()`) evaluation.
- **Flutter Integration**: Reactive `KnapMarkdownView` and `KnapBuilder` with real-time UI updates and syntax error diagnostics.
- **Built-in CLI**: `dart run knap render <template.md> --data <data.json>`.

---

## Quick Start (Dart)

```dart
import 'package:knap/knap.dart';

void main() {
  final engine = KnapEngine.standard();

  const template = '''
# {{ title | trim }}

> [!INFO] Summary
> {{ summary }}

## Tags
{{ tags | list }}

## Highlights
{% for h in highlights -%}
- {{ h.text }} ({{ h.note | default: "No note" }})
{% endfor %}

## Related Links
{% for link in links -%}
- {{ link.title | wikilink }}
{% endfor %}
''';

  final markdown = engine.render(template, data: {
    'title': '  Understanding Knap Engine  ',
    'summary': 'A safe, fast template language for Markdown.',
    'tags': ['obsidian', 'markdown', 'dart'],
    'highlights': [
      {'text': 'Zero eval safety', 'note': 'Crucial for apps'},
      {'text': 'Markdown optimized', 'note': null},
    ],
    'links': [
      {'title': 'Obsidian Clipper Docs'},
    ],
  });

  print(markdown);
}
```

---

## Quick Start (Flutter)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_knap/flutter_knap.dart';

class NotePreviewScreen extends StatelessWidget {
  const NotePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Knap Live Preview')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: KnapMarkdownView(
          template: '# {{ title }}\n\n{{ tags | list }}',
          data: {
            'title': 'My Captured Note',
            'tags': ['mobile', 'offline'],
          },
        ),
      ),
    );
  }
}
```

---

## CLI Usage

```bash
# Render inline template
dart run knap render --template "Hello {{ name | upper }}!" --data '{"name": "obsidian"}'

# Render template file with JSON data file
dart run knap render template.md --data data.json --output note.md
```

---

## Testing

```bash
# Core package
cd packages/knap && dart test

# Flutter package
cd packages/flutter_knap && flutter test
```
