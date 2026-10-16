import 'dart:convert';
import 'dart:io';
import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('Upstream Portable Compatibility (render.json)', () {
    final file = File('test/fixtures/render.json');
    if (!file.existsSync()) {
      test('fixtures/render.json exists', () {
        fail('test/fixtures/render.json not found');
      });
      return;
    }

    final jsonContent = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final cases = jsonContent['cases'] as List<dynamic>;

    final engine = KnapEngine.standard();

    for (final rawCase in cases) {
      final c = rawCase as Map<String, dynamic>;
      final id = c['id'] as String;
      final template = c['template'] as String;
      final variables = (c['variables'] as Map<String, dynamic>?) ?? {};
      final expected = c['expected'] as Map<String, dynamic>;

      test(id, () {
        final result = engine.renderWithDiagnostics(template, data: variables);
        final actual = {
          'output': result.output,
          'errors': result.errors.map((e) => e.code.code).toList(),
          'warnings': result.warnings.map((w) => {'code': w.code.code, 'filter': w.filter}).toList(),
        };
        expect(actual, equals(expected), reason: 'Template: $template');
      });
    }
  });
}
