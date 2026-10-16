# Knap for Dart

[![pub package](https://img.shields.io/pub/v/knap.svg)](https://pub.dev/packages/knap)
[![test](https://img.shields.io/badge/tests-309%20passed-success)](https://github.com/JAICHANGPARK/knap-dart)
[![coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)](https://github.com/JAICHANGPARK/knap-dart)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A simple, fast, and safe template language for turning structured data into Markdown using variables, filters, and logic.
Directly inspired by and 100% feature-compatible with [Obsidian Knap](https://github.com/obsidianmd/knap).

---

## Features

- **100% Upstream Conformance**: Passes 100% (188/188) of official cross-language `obsidianmd/knap` test suite fixtures (`render.json`).
- **91 Built-in Filters**:
  - **Standard (60+)**: String case conversion (`camel`, `snake`, `kebab`, `pascal`, `title`), formatting, `calc` math evaluator, Day.js date parsing & formatting, durations, regex `replace`, collections (`map`, `where`, `sort`, `slice`, `nth`, `unique`, `merge`), YAML, JSON.
  - **Markdown (25+)**: `wikilink`, `embed`, `table` / `table_pretty`, `callout`, `task_list`, `list`, `quote`, `tag`, `footnote`, `code` / `code_block`, `escape_md`, `stripmd`.
  - **HTML**: `strip_attr`, `remove_attr`, `replace_tags`, `html_to_json`.
- **AST Safety & Zero Eval**: Pure AST-based interpreter with no `eval()` or arbitrary code execution.
- **Resource Protection & Limits**: Built-in `RenderLimits` (`maxExecutionTimeMs`, `maxIterations`, `maxOutputLength`, `maxCallStackDepth`) to guard against runaway loops and excessive memory consumption.
- **Smart Diagnostics & Typo Suggestions**: `validate()`, `validateFilters()`, and `validateVariables()` with Levenshtein-distance fuzzy suggestions (e.g. `{{ x | uper }}` -> `"Did you mean \"upper\"?"`).
- **Rich Logic & Statements**:
  - `if / elif / else` branching
  - `for ... in ... else` loops with full loop metadata (`loop.index`, `loop.index0`, `loop.first`, `loop.last`, `loop.length`, `loop.even`, `loop.odd`)
  - `{% set variable = expression %}`, `{% break %}`, `{% continue %}`
- **Whitespace Control**: Jinja/Liquid-compatible `{{- -}}` and `{%- -%}` trimming.
- **Sync & Async Engine**: Synchronous `render()` and asynchronous `renderAsync()` supporting custom async filters.
- **Built-in CLI**: Standalone command-line utility with JSON and RFC 4180 CSV input support.

---

## Installation

Add `knap` to your `pubspec.yaml`:

```yaml
dependencies:
  knap: ^2026.10.17
```

Then run:

```bash
dart pub get
```

---

## Usage Example

### Basic Rendering

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
- {{ h.text }} (Priority: {{ h.priority | default: 1 }})
{% endfor %}

## Related Links
{% for link in links -%}
- {{ link | wikilink }}
{% endfor %}

## Created At
Formatted: {{ date | date: "YYYY-MM-DD HH:mm:ss" }}
''';

  final markdown = engine.render(template, data: {
    'title': '  understanding knap engine  ',
    'summary': 'A safe, fast template language for Markdown.',
    'tags': ['obsidian', 'markdown', 'dart'],
    'highlights': [
      {'text': 'Zero eval safety', 'priority': 5},
      {'text': 'Markdown optimized'},
    ],
    'links': [
      {'target': 'Documentation', 'alias': 'Official Docs'},
    ],
    'date': '2026-10-17T12:00:00Z',
  });

  print(markdown);
}
```

### Template Diagnostics & Validation

```dart
final engine = KnapEngine.standard();

// Validate template syntax and filters before rendering
final errors = engine.validate('Hello {{ name | uper }}');
for (final error in errors) {
  print(error.message);
  // Prints: Unknown filter "uper". Did you mean "upper"?
}

// Render with full execution diagnostics
final result = engine.renderWithDiagnostics(template, data: data);
if (result.isSuccess) {
  print(result.output);
} else {
  print('Errors: ${result.errors}');
}
```

### Custom Filters (Sync & Async)

```dart
final registry = FilterRegistry()
  ..register('shout', (val, args) => '${val?.toString().toUpperCase()}!')
  ..registerAsync('fetch_snippet', (val, args) async {
    return await fetchSnippetFromNetwork(val.toString());
  });

final engine = KnapEngine(filterRegistry: registry);

// Synchronous render
final outSync = engine.render('{{ "hello" | shout }}');

// Asynchronous render
final outAsync = await engine.renderAsync('{{ url | fetch_snippet }}', data: {'url': 'https://example.com'});
```

---

## CLI Usage

Knap includes a built-in CLI for rendering templates directly in terminal scripts or build pipelines:

```bash
# Render inline template with JSON data
dart run knap render --template "Hello {{ name | upper }}!" --data '{"name": "obsidian"}'

# Render template file with JSON data file to output file
dart run knap render template.md --data data.json --output output.md

# Render template with CSV data (RFC 4180 format)
dart run knap render template.md --csv entries.csv --output table.md
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.
