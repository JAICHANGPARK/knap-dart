import 'package:flutter/material.dart';
import 'package:flutter_knap/flutter_knap.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('flutter_knap Widgets', () {
    testWidgets('KnapBuilder builds rendered markdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnapBuilder(
              template: 'Hello {{ name | upper }}!',
              data: const {'name': 'World'},
              builder: (context, markdown, error) {
                return Text(markdown);
              },
            ),
          ),
        ),
      );

      expect(find.text('Hello WORLD!'), findsOneWidget);
    });

    testWidgets('KnapMarkdownView renders MarkdownBody widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KnapMarkdownView(
              template: '# {{ title }}\n\n{{ tags | list }}',
              data: {
                'title': 'Test Title',
                'tags': ['Tag1', 'Tag2'],
              },
            ),
          ),
        ),
      );

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.textContaining('Test Title'), findsOneWidget);
    });

    testWidgets('KnapMarkdownView displays error UI when syntax is invalid', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KnapMarkdownView(
              template: '{% if broken',
              data: {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('KnapError'), findsOneWidget);
    });

    testWidgets('KnapTemplateController updates dynamically', (tester) async {
      final controller = KnapTemplateController(
        initialTemplate: 'Count: {{ count }}',
        initialData: {'count': 1},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnapMarkdownView(
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.textContaining('Count: 1'), findsOneWidget);

      controller.data = {'count': 2};
      await tester.pump();

      expect(find.textContaining('Count: 2'), findsOneWidget);
    });
  });
}
