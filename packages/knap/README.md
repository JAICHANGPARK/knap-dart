# Knap for Dart

A simple, fast, and safe template language for turning data into Markdown using variables, filters, and logic.
Inspired by [Obsidian Knap](https://github.com/obsidianmd/knap).

## Features

- **Safe Execution**: AST-based interpreter with zero `eval` or arbitrary JavaScript/Dart code execution.
- **Markdown-first**: Built-in filters for `wikilink`, `list`, `task_list`, `table`, `callout`, `quote`, `tag`, and `escape_md`.
- **Whitespace Trimming**: Liquid/Jinja-compatible `{{- -}}` and `{%- -%}` whitespace control.
- **Variables & Statements**: Property and index access, plus `{% set name = expr %}`.
- **Comments**: `{# comment #}` and `{#- comment -#}`.
- **Rich Logic**: `if / elif / else` branching, `for ... in ... else` loops with loop variables (`loop.index`, `loop.first`, `loop.last`, `loop.revindex`, etc.).
- **Extended Filters**: Date formatting (`date`, `date_modify`), case conversion (`snake`, `camel`, `kebab`, `pascal`), and data manipulation (`merge`, `unique`, `yaml`, `hard_break`).
- **Async Filter Support**: Both synchronous (`render()`) and asynchronous (`renderAsync()`) evaluation.
- **Built-in CLI**: `dart run knap render <template.md> --data <data.json>`.

## Getting Started

Add `knap` to your `pubspec.yaml`:

```yaml
dependencies:
  knap: ^2026.9.25
```

## Usage Example

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

## CLI Usage

```bash
# Render inline template
dart run knap render --template "Hello {{ name | upper }}!" --data '{"name": "obsidian"}'

# Render template file with JSON data file
dart run knap render template.md --data data.json --output note.md
```
