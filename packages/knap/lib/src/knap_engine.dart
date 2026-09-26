import 'ast/ast.dart';
import 'filters/filter.dart';
import 'filters/markdown_filters.dart';
import 'filters/standard_filters.dart';
import 'lexer/lexer.dart';
import 'parser/parser.dart';
import 'runtime/context.dart';
import 'runtime/evaluator.dart';

/// A compiled, reusable Knap template holding the parsed abstract syntax tree ([ast]).
class KnapTemplate {
  /// The original source template string.
  final String source;

  /// The parsed root nodes making up this template.
  final List<KnapNode> ast;

  /// Creates a [KnapTemplate] with the given [source] and compiled [ast].
  const KnapTemplate({required this.source, required this.ast});

  /// Evaluates this template synchronously with optional [data] and custom [filters].
  String render({Map<String, Object?>? data, FilterRegistry? filters}) {
    final context = KnapContext(
      variables: data,
      filterRegistry: filters,
    );
    final evaluator = KnapEvaluator(context);
    return evaluator.evaluate(ast);
  }

  /// Evaluates this template asynchronously, supporting asynchronous filter pipelines.
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

/// The main entry point for compiling and rendering Knap Markdown templates.
class KnapEngine {
  /// The filter registry containing all active filters for this engine instance.
  final FilterRegistry filterRegistry;

  /// Creates a [KnapEngine] with optional custom synchronous [filters] and [asyncFilters].
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

  /// Creates an engine pre-configured with all standard, web clipper, and markdown filters.
  factory KnapEngine.standard() {
    return KnapEngine(
      filters: {
        ...standardFilters,
        ...markdownFilters,
      },
    );
  }

  /// Parses and compiles a template [source] string into a reusable [KnapTemplate].
  KnapTemplate compile(String source) {
    final lexer = KnapLexer(source);
    final tokens = lexer.scanTokens();
    final parser = KnapParser(tokens);
    final ast = parser.parse();
    return KnapTemplate(source: source, ast: ast);
  }

  /// Compiles and renders a template [source] synchronously with provided [data].
  String render(String source, {Map<String, Object?>? data}) {
    final template = compile(source);
    return template.render(data: data, filters: filterRegistry);
  }

  /// Compiles and renders a template [source] asynchronously with provided [data].
  Future<String> renderAsync(String source, {Map<String, Object?>? data}) async {
    final template = compile(source);
    return await template.renderAsync(data: data, filters: filterRegistry);
  }
}
