import 'package:knap/knap.dart';

void main() async {
  print('=== 1. Basic Variable & Filter Chaining ===');
  final engine = KnapEngine.standard();
  final basicResult = engine.render(
    'Hello {{ user.name | trim | upper }}! Your slug is: {{ user.name | slug }}',
    data: {
      'user': {'name': '  Jane Developer  '},
    },
  );
  print(basicResult);
  print('');

  print('=== 2. Obsidian Web Clipper Scenario ===');
  const clipperTemplate = '''---
title: {{ title | yaml }}
author: "{{ author | default: "Anonymous" }}"
clipped_at: "{{ "now" | date: "YYYY-MM-DD HH:mm" }}"
review_due: "{{ "now" | date_modify: "+7 days" | date: "YYYY-MM-DD" }}"
tags:
{{ tags | list }}
---

# {{ title }}

> [!INFO] Summary
> {{ summary | hard_break }}

## Action Items
{{ tasks | task_list }}

## Highlights
{% for item in highlights -%}
> {{ item.quote | quote }}
  — Note: {{ item.comment | default: "None" }}
{% endfor %}

## Related Notes
{% for link in related_notes -%}
- {{ link | wikilink }}
{% endfor %}
''';

  final clipperData = {
    'title': 'Effective Dart & Flutter Architecture in 2026',
    'author': 'Alex Rivers',
    'tags': ['flutter', 'dart', 'architecture', 'best-practices'],
    'summary': 'A comprehensive deep dive into scalable Flutter patterns.\nHighly recommended for team leads.',
    'tasks': [
      {'title': 'Refactor repository layer to use sealed classes', 'done': true},
      {'title': 'Add integration tests for Knap engine', 'done': false},
      {'title': 'Publish package to pub.dev', 'done': true},
    ],
    'highlights': [
      {
        'quote': 'Keep business logic decoupled from presentation widgets.',
        'comment': 'Aligns with our team standards',
      },
      {
        'quote': 'Zero eval AST interpreters are secure and mobile-safe.',
        'comment': null,
      },
    ],
    'related_notes': ['Dart Patterns Guide', 'Obsidian PKM Workflow'],
  };

  print(engine.render(clipperTemplate, data: clipperData));

  print('=== 3. Table & Array Operations ===');
  const tableTemplate = '''
## Team Members
{{ members | table }}
''';

  final tableData = {
    'members': [
      {'Name': 'Alice', 'Role': 'Tech Lead', 'Status': 'Active'},
      {'Name': 'Bob', 'Role': 'Designer', 'Status': 'Active'},
      {'Name': 'Charlie', 'Role': 'DevOps', 'Status': 'On Leave'},
    ],
  };
  print(engine.render(tableTemplate, data: tableData));

  print('=== 4. Custom Filters (Sync & Async) ===');
  final customEngine = KnapEngine(
    filters: {
      ...standardFilters,
      'badge': (val, args) {
        final color = args.isNotEmpty ? args[0] : 'blue';
        return '![$val](https://img.shields.io/badge/$val-$color)';
      },
    },
    asyncFilters: {
      'fetchStars': (repo, args) async {
        // Simulating async network lookup
        await Future.delayed(const Duration(milliseconds: 50));
        return '⭐ 1.2k stars for $repo';
      },
    },
  );

  final customResult = await customEngine.renderAsync(
    'Status: {{ "Passing" | badge: "green" }}\nInfo: {{ "JAICHANGPARK/knap-dart" | fetchStars }}',
  );
  print(customResult);
}
