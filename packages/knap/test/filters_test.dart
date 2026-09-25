import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('Standard and Markdown Filters', () {
    final engine = KnapEngine.standard();

    test('wikilink filter', () {
      expect(
        engine.render('{{ title | wikilink }}', data: {'title': 'My Note'}),
        '[[My Note]]',
      );
      expect(
        engine.render('{{ title | wikilink: "Alias" }}', data: {'title': 'My Note'}),
        '[[My Note|Alias]]',
      );
    });

    test('list filter', () {
      final result = engine.render('{{ tags | list }}', data: {
        'tags': ['apple', 'banana', 'cherry'],
      });
      expect(result, '- apple\n- banana\n- cherry');
    });

    test('task_list filter', () {
      final result = engine.render('{{ tasks | task_list }}', data: {
        'tasks': [
          {'title': 'Task 1', 'done': true},
          {'title': 'Task 2', 'done': false},
        ],
      });
      expect(result, '- [x] Task 1\n- [ ] Task 2');
    });

    test('callout filter', () {
      final result = engine.render('{{ note | callout: "TIP", "Important Tip" }}', data: {
        'note': 'Do not forget this.',
      });
      expect(result, '> [!TIP] Important Tip\n> Do not forget this.');
    });

    test('table filter', () {
      final result = engine.render('{{ users | table }}', data: {
        'users': [
          {'name': 'Alice', 'role': 'Admin'},
          {'name': 'Bob', 'role': 'User'},
        ],
      });
      expect(result, contains('| name | role |'));
      expect(result, contains('| Alice | Admin |'));
      expect(result, contains('| Bob | User |'));
    });

    test('slug filter', () {
      expect(
        engine.render('{{ title | slug }}', data: {'title': 'Hello World & Everyone!'}),
        'hello-world-everyone',
      );
    });

    test('truncate and default filters', () {
      expect(
        engine.render('{{ text | truncate: 5 }}', data: {'text': 'Hello World'}),
        'Hello...',
      );
      expect(
        engine.render('{{ missing | default: "N/A" }}', data: {}),
        'N/A',
      );
    });
  });
}
