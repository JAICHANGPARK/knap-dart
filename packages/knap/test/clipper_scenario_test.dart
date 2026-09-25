import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('Obsidian Web Clipper Real-world Scenario', () {
    final engine = KnapEngine.standard();

    test('renders complex web clipper template with frontmatter and markdown filters', () {
      const template = '''---
title: "{{ title | replace: '"', '\\"' }}"
url: "{{ url }}"
clipped_at: "{{ date }}"
tags:
{{ tags | list }}
---

# {{ title }}

> [!INFO] Summary
> {{ summary }}

## Highlights
{% for h in highlights -%}
- {{ h.text }} ({{ h.note | default: "No note" }})
{% endfor %}

## Related Links
{% for link in links -%}
- {{ link.title | wikilink }}
{% endfor %}
''';

      final data = {
        'title': 'Understanding Knap Engine',
        'url': 'https://knap.md',
        'date': '2026-09-25',
        'tags': ['obsidian', 'markdown', 'dart'],
        'summary': 'A safe, fast template language for Markdown.',
        'highlights': [
          {'text': 'Zero eval safety', 'note': 'Crucial for mobile and web'},
          {'text': 'Markdown optimized', 'note': null},
        ],
        'links': [
          {'title': 'Obsidian Clipper Docs'},
          {'title': 'Dart 3 Patterns'},
        ],
      };

      final result = engine.render(template, data: data);

      expect(result, contains('title: "Understanding Knap Engine"'));
      expect(result, contains('- obsidian\n- markdown\n- dart'));
      expect(result, contains('> [!INFO] Summary\n> A safe, fast template language for Markdown.'));
      expect(result, contains('- Zero eval safety (Crucial for mobile and web)'));
      expect(result, contains('- Markdown optimized (No note)'));
      expect(result, contains('- [[Obsidian Clipper Docs]]'));
      expect(result, contains('- [[Dart 3 Patterns]]'));
    });
  });
}
