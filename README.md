# Knap for Dart & Flutter

[![Dart SDK](https://img.shields.io/badge/Dart-3.5+-blue.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B.svg)](https://flutter.dev)
[![pub knap](https://img.shields.io/pub/v/knap.svg?label=knap)](https://pub.dev/packages/knap)
[![pub flutter_knap](https://img.shields.io/pub/v/flutter_knap.svg?label=flutter_knap)](https://pub.dev/packages/flutter_knap)
[![tests](https://img.shields.io/badge/tests-319%20passed-success)](https://github.com/JAICHANGPARK/knap-dart)
[![coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)](https://github.com/JAICHANGPARK/knap-dart)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A simple, fast, and safe template engine for turning structured data into Markdown using variables, filters, and logic.
Inspired by and 100% feature-compatible with [Obsidian Knap](https://github.com/obsidianmd/knap).

---

## Packages

| Package | Version | Description | Path |
|---|---|---|---|
| [`knap`](packages/knap) | [![pub package](https://img.shields.io/pub/v/knap.svg)](https://pub.dev/packages/knap) | Core pure Dart template engine, 91 built-in filters & CLI | [`packages/knap`](packages/knap) |
| [`flutter_knap`](packages/flutter_knap) | [![pub package](https://img.shields.io/pub/v/flutter_knap.svg)](https://pub.dev/packages/flutter_knap) | Reactive Flutter widgets & live Markdown preview tools | [`packages/flutter_knap`](packages/flutter_knap) |

---

## Highlights & Features

- **100% Upstream Conformance**: Passes 100% (188/188) of official cross-language `obsidianmd/knap` test suite fixtures (`render.json`).
- **91 Built-in Filters**:
  - **Standard (60+)**: String case conversions (`camel`, `snake`, `kebab`, `pascal`, `title`), formatting, `calc` mathematical evaluator, Day.js date parsing & formatting, durations, regex `replace`, collections (`map`, `where`, `sort`, `slice`, `nth`, `unique`, `merge`), YAML, JSON.
  - **Markdown (25+)**: `wikilink`, `embed`, `table` / `table_pretty`, `callout`, `task_list`, `list`, `quote`, `tag`, `footnote`, `code` / `code_block`, `escape_md`, `stripmd`.
  - **HTML**: `strip_attr`, `remove_attr`, `replace_tags`, `html_to_json`.
- **AST Safety & Zero Eval**: Pure AST-based interpreter with no `eval()` or arbitrary runtime code execution.
- **Resource Protection**: Configurable `RenderLimits` (`maxExecutionTimeMs`, `maxIterations`, `maxOutputLength`, `maxCallStackDepth`) to prevent runaway loops.
- **Smart Diagnostics & Typo Suggestions**: Levenshtein-distance fuzzy matching suggests close filter names (e.g. `{{ x | uper }}` -> `"Did you mean \"upper\"?"`).
- **Rich Logic & Statements**:
  - `if / elif / else` branching
  - `for ... in ... else` loops with loop variables (`loop.index`, `loop.first`, `loop.last`, `loop.length`, `loop.even`, `loop.odd`, etc.)
  - `{% set %}`, `{% break %}`, `{% continue %}`
- **Whitespace Control**: Jinja/Liquid-compatible `{{- -}}` and `{%- -%}` trimming.
- **Sync & Async Engine**: Synchronous `render()` and asynchronous `renderAsync()` with support for custom async filters.
- **Flutter Widgets**: Reactive `KnapMarkdownView` and `KnapBuilder` with real-time UI updates, custom styles, and visual error reporting.
- **Built-in CLI**: Standalone command-line utility with JSON and RFC 4180 CSV input support.

---

## Quick Start (Dart)

Add `knap` to your `pubspec.yaml`:

```yaml
dependencies:
  knap: ^2026.10.17
```

```dart
import 'package:knap/knap.dart';

void main() {
  final engine = KnapEngine.standard();

  const template = '''
# {{ title | trim | title }}

> [!INFO] Quick Summary
> {{ summary }}

## Tags
{{ tags | list }}

## Highlights
{% for h in highlights -%}
- {{ h.text }} ({{ h.note | default: "General" }})
{% endfor %}

## Related Links
{% for link in links -%}
- {{ link | wikilink }}
{% endfor %}

## Metadata
- Date: {{ date | date: "YYYY-MM-DD" }}
- Status: {{ status | upper }}
''';

  final markdown = engine.render(template, data: {
    'title': '  understanding knap engine  ',
    'summary': 'A safe, fast template language for Markdown.',
    'tags': ['obsidian', 'markdown', 'dart'],
    'highlights': [
      {'text': 'Zero eval safety', 'note': 'Crucial for apps'},
      {'text': 'Markdown optimized'},
    ],
    'links': [
      {'target': 'Documentation', 'alias': 'Docs'},
    ],
    'date': '2026-10-17T00:00:00Z',
    'status': 'published',
  });

  print(markdown);
}
```

---

## Quick Start (Flutter)

Add `flutter_knap` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_knap: ^2026.10.17
```

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
          selectable: true,
        ),
      ),
    );
  }
}
```

---

## CLI Usage

```bash
# Render inline template with JSON data
dart run knap render --template "Hello {{ name | upper }}!" --data '{"name": "obsidian"}'

# Render template file with JSON data file
dart run knap render template.md --data data.json --output note.md

# Render template with CSV data (RFC 4180)
dart run knap render template.md --csv data.csv --output table.md
```

---

## Testing & Verification

```bash
# Run tests and verify 100% coverage on core package
cd packages/knap
dart test
dart run coverage:test_with_coverage

# Run tests on Flutter package
cd ../flutter_knap
flutter test --coverage
```

- **Line coverage**: 100.00% across all library files
- **Static analysis**: 0 warnings, 0 errors (`dart analyze` & `flutter analyze` clean)

---

## License

MIT License. See [LICENSE](LICENSE) for details.
