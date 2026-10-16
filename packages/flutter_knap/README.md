# Flutter Knap

[![pub package](https://img.shields.io/pub/v/flutter_knap.svg)](https://pub.dev/packages/flutter_knap)
[![test](https://img.shields.io/badge/tests-10%20passed-success)](https://github.com/JAICHANGPARK/knap-dart)
[![coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)](https://github.com/JAICHANGPARK/knap-dart)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Reactive Flutter widgets and real-time Markdown preview tools for the [Knap](https://pub.dev/packages/knap) template engine.
Render safe, data-driven templates directly into styled, interactive Markdown views.

---

## Features

- **`KnapMarkdownView`**: Direct rendering of Knap templates and JSON data into styled, selectable Markdown with `flutter_markdown`.
  - Configurable `MarkdownStyleSheet`.
  - Built-in visual syntax error diagnostics with monospace reporting.
  - Custom `errorBuilder` for domain-specific error presentation.
- **`KnapBuilder`**: Dynamic builder widget that reacts to template compilation, execution status, and data changes.
- **`KnapTemplateController`**: Reactive `ChangeNotifier` for real-time synchronization between editor textfields, dynamic data inputs, and preview panes.

---

## Installation

Add `flutter_knap` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_knap: ^2026.10.17
```

Then run:

```bash
flutter pub get
```

---

## Usage Examples

### 1. Direct Markdown Preview (`KnapMarkdownView`)

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
          template: '''
# {{ title | trim | title }}

> [!NOTE] Quick Info
> {{ summary }}

## Tags
{{ tags | list }}

## Highlights
{% for h in highlights -%}
- {{ h.text }} ({{ h.note | default: "No note" }})
{% endfor %}
''',
          data: {
            'title': 'understanding knap in flutter',
            'summary': 'Extracted via Knap template in Flutter.',
            'tags': ['flutter', 'knap', 'markdown'],
            'highlights': [
              {'text': 'Safe AST execution', 'note': 'Zero eval'},
              {'text': 'Reactive previews'},
            ],
          },
          selectable: true,
        ),
      ),
    );
  }
}
```

### 2. Interactive Editing with `KnapTemplateController` & `KnapBuilder`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_knap/flutter_knap.dart';

class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({super.key});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  late final KnapTemplateController _controller;

  @override
  void initState() {
    super.initState();
    _controller = KnapTemplateController(
      template: 'Hello **{{ name | upper }}**!',
      data: {'name': 'World'},
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Knap Template Controller')),
      body: Column(
        children: [
          TextField(
            onChanged: (text) => _controller.update(template: text),
            decoration: const InputDecoration(labelText: 'Template input'),
          ),
          Expanded(
            child: KnapBuilder(
              controller: _controller,
              builder: (context, renderedMarkdown) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(renderedMarkdown),
                );
              },
              errorBuilder: (context, error) {
                return Text('Error: ${error.message}', style: const TextStyle(color: Colors.red));
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Testing

```bash
flutter test --coverage
```

Achieves **100.00% line coverage** with zero analyzer warnings.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
