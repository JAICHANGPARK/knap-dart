import 'ast/ast.dart';
import 'filters/filter.dart';
import 'filters/markdown_filters.dart';
import 'filters/standard_filters.dart';
import 'lexer/lexer.dart';
import 'parser/parser.dart';
import 'runtime/context.dart';
import 'runtime/evaluator.dart';

class KnapTemplate {
  final String source;
  final List<KnapNode> ast;

  const KnapTemplate({required this.source, required this.ast});

  String render({Map<String, Object?>? data, FilterRegistry? filters}) {
    final context = KnapContext(
      variables: data,
      filterRegistry: filters,
    );
    final evaluator = KnapEvaluator(context);
    return evaluator.evaluate(ast);
  }

  Future<String> renderAsync({
    Map<String, Object?>? data,
    FilterRegistry? filters,
  }) async {
    final context = KnapContext(
      variables: data,
      filterRegistry: filters,
    );
    final evaluator = KnapEvaluator(context);
    return await evaluator.evaluateAsync(ast);
  }
}

class KnapEngine {
  final FilterRegistry filterRegistry;

  KnapEngine({
    Map<String, KnapFilter>? filters,
    Map<String, KnapAsyncFilter>? asyncFilters,
  }) : filterRegistry = FilterRegistry() {
    if (filters != null) {
      for (final entry in filters.entries) {
        filterRegistry.register(entry.key, entry.value);
      }
    }
    if (asyncFilters != null) {
      for (final entry in asyncFilters.entries) {
        filterRegistry.registerAsync(entry.key, entry.value);
      }
    }
  }

  /// Creates an engine with all standard string, collection, and markdown filters.
  factory KnapEngine.standard() {
    return KnapEngine(
      filters: {
        ...standardFilters,
        ...markdownFilters,
      },
    );
  }

  /// Parses and compiles a template string into an AST template for reuse.
  KnapTemplate compile(String source) {
    final lexer = KnapLexer(source);
    final tokens = lexer.scanTokens();
    final parser = KnapParser(tokens);
    final ast = parser.parse();
    return KnapTemplate(source: source, ast: ast);
  }

  /// Compiles and renders a template string synchronously.
  String render(String source, {Map<String, Object?>? data}) {
    final template = compile(source);
    return template.render(data: data, filters: filterRegistry);
  }

  /// Compiles and renders a template string asynchronously.
  Future<String> renderAsync(String source, {Map<String, Object?>? data}) async {
    final template = compile(source);
    return await template.renderAsync(data: data, filters: filterRegistry);
  }
}
