/// A simple, safe template language that turns data into Markdown using
/// variables, filters, and control flow logic.
///
/// Use [KnapEngine.standard] to render templates with all 91 built-in
/// string, collection, date, HTML, and Obsidian Markdown filters:
///
/// @docImport 'src/knap_engine.dart';
///
/// ```dart
/// import 'package:knap/knap.dart';
///
/// void main() {
///   final engine = KnapEngine.standard();
///   final markdown = engine.render(
///     '# {{ title | trim }}\nTags: {{ tags | wikilink | join:", " }}',
///     data: {
///       'title': '  Obsidian Web Clipper  ',
///       'tags': ['knowledge-base', 'markdown'],
///     },
///   );
///   print(markdown);
/// }
/// ```
library;

export 'src/ast/ast.dart';
export 'src/cli/csv_parser.dart';
export 'src/errors/exceptions.dart';
export 'src/filters/filter.dart';
export 'src/filters/html_filters.dart';
export 'src/filters/markdown_filters.dart';
export 'src/filters/standard_filters.dart';
export 'src/knap_engine.dart';
export 'src/lexer/lexer.dart';
export 'src/limits/render_limits.dart';
export 'src/parser/parser.dart';
export 'src/runtime/context.dart';
export 'src/runtime/evaluator.dart';
export 'src/tokens/token.dart';
