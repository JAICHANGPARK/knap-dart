# Flutter Knap

Flutter widgets and real-time Markdown preview tools for the [Knap](https://pub.dev/packages/knap) template engine.

## Features

- **`KnapMarkdownView`**: Directly render Knap templates and JSON data into rich, styled Markdown with `flutter_markdown`.
- **`KnapBuilder`**: Build custom widgets dynamically based on Knap template state and compilation results.
- **`KnapTemplateController`**: Reactive `ChangeNotifier` providing real-time re-rendering when templates or data change, with built-in syntax error diagnostics.

## Getting Started

Add `flutter_knap` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_knap: ^2026.9.25
```

## Usage Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_knap/flutter_knap.dart';

class NotePreviewScreen extends StatelessWidget {
  const NotePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Note Preview')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: KnapMarkdownView(
          template: '''
# {{ title | trim }}

> [!NOTE] Quick Info
> {{ summary }}

## Tags
{{ tags | list }}
''',
          data: {
            'title': 'Captured Article',
            'summary': 'Extracted via Knap template in Flutter.',
            'tags': ['flutter', 'knap', 'markdown'],
          },
        ),
      ),
    );
  }
}
```
