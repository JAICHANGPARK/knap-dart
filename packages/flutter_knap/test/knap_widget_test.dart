import 'package:flutter/material.dart';
import 'package:flutter_knap/flutter_knap.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingEngine extends KnapEngine {
  _FailingEngine() : super(filters: {});

  @override
  String render(String template, {Map<String, Object?>? data}) {
    throw StateError('Engine exploded');
  }
}

void main() {
  group('KnapTemplateController', () {
    test('initializes with default values', () {
      final controller = KnapTemplateController();
      expect(controller.template, isEmpty);
      expect(controller.data, isEmpty);
      expect(controller.output, isEmpty);
      expect(controller.error, isNull);
      expect(controller.hasError, isFalse);
    });

    test('getters and setters work correctly', () {
      final controller = KnapTemplateController(
        initialTemplate: 'Hello {{ name }}',
        initialData: {'name': 'World'},
      );
      expect(controller.template, 'Hello {{ name }}');
      expect(controller.data, {'name': 'World'});
      expect(controller.output, 'Hello World');
      expect(controller.hasError, isFalse);

      // Setter with same template should not re-render
      controller.template = 'Hello {{ name }}';
      expect(controller.output, 'Hello World');

      // Setter with new template
      controller.template = 'Hi {{ name }}';
      expect(controller.output, 'Hi World');

      // Setter with data
      controller.data = {'name': 'Flutter'};
      expect(controller.output, 'Hi Flutter');
    });

    test('update method handles partial and identical updates', () {
      final controller = KnapTemplateController(
        initialTemplate: 'Val: {{ val }}',
        initialData: {'val': 10},
      );

      // No change
      controller.update();
      expect(controller.output, 'Val: 10');

      // Same template, no change
      controller.update(template: 'Val: {{ val }}');
      expect(controller.output, 'Val: 10');

      // Update only template
      controller.update(template: 'Value is {{ val }}');
      expect(controller.output, 'Value is 10');

      // Update only data
      controller.update(data: {'val': 20});
      expect(controller.output, 'Value is 20');

      // Update both
      controller.update(template: 'Final: {{ val }}', data: {'val': 30});
      expect(controller.output, 'Final: 30');
    });

    test('catches non-KnapException during render', () {
      final controller = KnapTemplateController(
        initialTemplate: 'test',
        engine: _FailingEngine(),
      );

      expect(controller.hasError, isTrue);
      expect(controller.error, isA<KnapEvaluationException>());
      expect(controller.error.toString(), contains('Engine exploded'));
    });
  });

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

    testWidgets('KnapBuilder updates when template or data properties change', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnapBuilder(
              template: 'A: {{ x }}',
              data: const {'x': 1},
              builder: (context, markdown, error) => Text(markdown),
            ),
          ),
        ),
      );
      expect(find.text('A: 1'), findsOneWidget);

      // Rebuild with new template and data
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnapBuilder(
              template: 'B: {{ x }}',
              data: const {'x': 2},
              builder: (context, markdown, error) => Text(markdown),
            ),
          ),
        ),
      );
      expect(find.text('B: 2'), findsOneWidget);
    });

    testWidgets('KnapBuilder switches between external controllers smoothly', (tester) async {
      final controller1 = KnapTemplateController(
        initialTemplate: 'Ctrl 1: {{ val }}',
        initialData: {'val': 'first'},
      );
      final controller2 = KnapTemplateController(
        initialTemplate: 'Ctrl 2: {{ val }}',
        initialData: {'val': 'second'},
      );

      // First controller
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnapBuilder(
              controller: controller1,
              builder: (context, markdown, error) => Text(markdown),
            ),
          ),
        ),
      );
      expect(find.text('Ctrl 1: first'), findsOneWidget);

      // Switch to second controller
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnapBuilder(
              controller: controller2,
              builder: (context, markdown, error) => Text(markdown),
            ),
          ),
        ),
      );
      expect(find.text('Ctrl 2: second'), findsOneWidget);

      // Switch from external controller to internal controller
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnapBuilder(
              template: 'Internal: {{ val }}',
              data: const {'val': 'third'},
              builder: (context, markdown, error) => Text(markdown),
            ),
          ),
        ),
      );
      expect(find.text('Internal: third'), findsOneWidget);

      // Switch back to external controller (disposes internal controller)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnapBuilder(
              controller: controller1,
              builder: (context, markdown, error) => Text(markdown),
            ),
          ),
        ),
      );
      expect(find.text('Ctrl 1: first'), findsOneWidget);
    });

    testWidgets('KnapMarkdownView renders MarkdownBody widget with styles and selectable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KnapMarkdownView(
              template: '# {{ title }}\n\n{{ tags | list }}',
              data: {
                'title': 'Test Title',
                'tags': ['Tag1', 'Tag2'],
              },
              selectable: false,
              styleSheet: null,
            ),
          ),
        ),
      );

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.textContaining('Test Title'), findsOneWidget);
    });

    testWidgets('KnapMarkdownView displays default error UI when syntax is invalid', (tester) async {
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

    testWidgets('KnapMarkdownView displays custom errorBuilder when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnapMarkdownView(
              template: '{% if broken',
              data: const {},
              errorBuilder: (context, error) {
                return Text('CUSTOM_ERROR: ${error.message}');
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('CUSTOM_ERROR:'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });
}
