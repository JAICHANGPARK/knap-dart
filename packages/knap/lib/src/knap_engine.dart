import 'ast/ast.dart';
import 'errors/exceptions.dart';
import 'filters/filter.dart';
import 'filters/html_filters.dart';
import 'filters/markdown_filters.dart';
import 'filters/standard_filters.dart';
import 'lexer/lexer.dart';
import 'limits/render_limits.dart';
import 'parser/parser.dart';
import 'runtime/context.dart';
import 'runtime/evaluator.dart';

/// Applies a pipe-separated [filterChain] (such as `"trim | upper"`) to [value] using [registry].
Object? applyFiltersWithRegistry(
  Object? value,
  String filterChain,
  FilterRegistry registry,
) {
  if (filterChain.trim().isEmpty) return value;
  final template = '{{ value | $filterChain }}';
  final lexer = KnapLexer(template);
  final tokens = lexer.scanTokens();
  final parser = KnapParser(tokens);
  final ast = parser.parse();
  if (ast.isEmpty || ast.first is! VariableNode) return value;
  final varNode = ast.first as VariableNode;
  final context = KnapContext(
    variables: {'value': value},
    filterRegistry: registry,
  );
  final evaluator = KnapEvaluator(context);
  var current = value;
  for (final filter in varNode.filters) {
    final args = filter.arguments.map((arg) {
      if (arg is LiteralExpression) return arg.value;
      if (arg is VariableExpression) return arg.name;
      return evaluator.evaluate([VariableNode(arg)]);
    }).toList();
    current = context.applyFilter(filter.name, current, args);
  }
  return current;
}

/// A compiled, reusable Knap template holding the parsed abstract syntax tree ([ast]).
class KnapTemplate {
  /// The original source template string.
  final String source;

  /// The parsed root nodes making up this template.
  final List<KnapNode> ast;

  /// Creates a [KnapTemplate] with the given [source] and compiled [ast].
  const KnapTemplate({required this.source, required this.ast});

  /// Evaluates this template synchronously with optional [data], custom [filters], [variableResolver], and [limits].
  String render({
    Map<String, Object?>? data,
    FilterRegistry? filters,
    KnapVariableResolver? variableResolver,
    RenderLimits limits = defaultRenderLimits,
  }) {
    final context = KnapContext(
      variables: data,
      filterRegistry: filters,
      variableResolver: variableResolver,
    );
    final evaluator = KnapEvaluator(context, limits: limits);
    return evaluator.evaluate(ast);
  }

  /// Evaluates this template asynchronously, supporting asynchronous filter pipelines and [asyncVariableResolver].
  Future<String> renderAsync({
    Map<String, Object?>? data,
    FilterRegistry? filters,
    KnapVariableResolver? variableResolver,
    KnapAsyncVariableResolver? asyncVariableResolver,
    RenderLimits limits = defaultRenderLimits,
  }) async {
    final context = KnapContext(
      variables: data,
      filterRegistry: filters,
      variableResolver: variableResolver,
      asyncVariableResolver: asyncVariableResolver,
    );
    final evaluator = KnapEvaluator(context, limits: limits);
    return await evaluator.evaluateAsync(ast);
  }
}

/// The main entry point for compiling, validating, and rendering Knap Markdown templates.
class KnapEngine {
  /// The filter registry containing all active filters for this engine instance.
  final FilterRegistry filterRegistry;

  /// Default resource and complexity limits enforced by this engine.
  final RenderLimits limits;

  /// Creates a [KnapEngine] with optional custom synchronous [filters], [asyncFilters], and [limits].
  KnapEngine({
    Map<String, KnapFilter>? filters,
    Map<String, KnapAsyncFilter>? asyncFilters,
    this.limits = defaultRenderLimits,
  }) : filterRegistry = FilterRegistry() {
    limits.validate();
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

  /// Creates an engine pre-configured with all standard, HTML, web clipper, and markdown filters.
  factory KnapEngine.standard({RenderLimits limits = defaultRenderLimits}) {
    return KnapEngine(
      filters: {
        ...standardFilters,
        ...markdownFilters,
        ...htmlFilters,
      },
      limits: limits,
    );
  }

  /// Parses and compiles a template [source] string into a reusable [KnapTemplate].
  KnapTemplate compile(String source, {RenderLimits? limits}) {
    final effectiveLimits = limits ?? this.limits;
    effectiveLimits.validate();
    if (source.length > effectiveLimits.maxTemplateLength) {
      throw const KnapLimitException('Template exceeded maxTemplateLength');
    }
    final lexer = KnapLexer(source);
    final tokens = lexer.scanTokens();
    final parser = KnapParser(tokens, limits: effectiveLimits);
    final ast = parser.parse();
    return KnapTemplate(source: source, ast: ast);
  }

  /// Compiles and renders a template [source] synchronously with provided [data].
  String render(
    String source, {
    Map<String, Object?>? data,
    KnapVariableResolver? variableResolver,
    RenderLimits? limits,
  }) {
    final effectiveLimits = limits ?? this.limits;
    final template = compile(source, limits: effectiveLimits);
    return template.render(
      data: data,
      filters: filterRegistry,
      variableResolver: variableResolver,
      limits: effectiveLimits,
    );
  }

  /// Compiles and renders a template [source] asynchronously with provided [data].
  Future<String> renderAsync(
    String source, {
    Map<String, Object?>? data,
    KnapVariableResolver? variableResolver,
    KnapAsyncVariableResolver? asyncVariableResolver,
    RenderLimits? limits,
  }) async {
    final effectiveLimits = limits ?? this.limits;
    final template = compile(source, limits: effectiveLimits);
    return await template.renderAsync(
      data: data,
      filters: filterRegistry,
      variableResolver: variableResolver,
      asyncVariableResolver: asyncVariableResolver,
      limits: effectiveLimits,
    );
  }

  /// Renders a template [source] without throwing, returning a structured [TemplateResult].
  TemplateResult renderWithDiagnostics(
    String source, {
    Map<String, Object?>? data,
    KnapVariableResolver? variableResolver,
    RenderLimits? limits,
  }) {
    try {
      final effectiveLimits = limits ?? this.limits;
      final template = compile(source, limits: effectiveLimits);
      final filterErrors = validateFilters(template.ast);
      if (filterErrors.isNotEmpty) {
        return TemplateResult(output: '', errors: filterErrors);
      }
      final context = KnapContext(
        variables: data,
        filterRegistry: filterRegistry,
        variableResolver: variableResolver,
      );
      final evaluator = KnapEvaluator(context, limits: effectiveLimits);
      final output = evaluator.evaluate(template.ast);
      return TemplateResult(
        output: output,
        errors: const [],
        warnings: List.unmodifiable(context.warnings),
      );
    } on KnapException catch (e) {
      return TemplateResult(
        output: '',
        errors: [
          TemplateError(
            message: e.message,
            line: e.location?.line ?? 1,
            column: e.location?.column ?? 1,
            code: e.code,
          ),
        ],
      );
    }
  }

  /// Renders a template [source] or throws a [KnapException] if any error occurs.
  String renderOrThrow(
    String source, {
    Map<String, Object?>? data,
    KnapVariableResolver? variableResolver,
    RenderLimits? limits,
  }) {
    return render(
      source,
      data: data,
      variableResolver: variableResolver,
      limits: limits,
    );
  }

  /// Statically validates template [source] for syntax errors, limit violations, and unknown filters.
  List<TemplateError> validate(String source, {RenderLimits? limits}) {
    try {
      final template = compile(source, limits: limits);
      return validateFilters(template.ast);
    } on KnapException catch (e) {
      return [
        TemplateError(
          message: e.message,
          line: e.location?.line ?? 1,
          column: e.location?.column ?? 1,
          code: e.code,
        ),
      ];
    }
  }

  /// Validates that all filters referenced in [ast] are registered in [filterRegistry].
  List<TemplateError> validateFilters(List<KnapNode> ast) {
    final errors = <TemplateError>[];
    void visitNodes(List<KnapNode> nodes) {
      for (final node in nodes) {
        switch (node) {
          case TextNode():
            break;
          case VariableNode(:final filters):
            for (final f in filters) {
              if (!filterRegistry.has(f.name)) {
                errors.add(
                  TemplateError(
                    message: 'Unknown filter "${f.name}"',
                    code: TemplateErrorCode.unknownFilter,
                  ),
                );
              }
            }
          case IfNode(
              :final thenBranch,
              :final elifBranches,
              :final elseBranch
            ):
            visitNodes(thenBranch);
            for (final elif in elifBranches) {
              visitNodes(elif.body);
            }
            visitNodes(elseBranch);
          case ForNode(:final body, :final elseBody):
            visitNodes(body);
            visitNodes(elseBody);
          case SetNode():
            break;
        }
      }
    }

    visitNodes(ast);
    return errors;
  }

  /// Validates that all top-level variables referenced in [ast] exist in [data] or local `{% set %}`/`{% for %}` scopes.
  List<TemplateError> validateVariables(
    List<KnapNode> ast,
    Map<String, Object?> data,
  ) {
    final errors = <TemplateError>[];
    final defined = <String>{
      ...data.keys,
      ...data.keys
          .where((k) => k.startsWith('{{') && k.endsWith('}}'))
          .map((k) => k.substring(2, k.length - 2)),
      'loop',
    };

    void visitExpr(Expression expr, Set<String> scopeVars) {
      switch (expr) {
        case LiteralExpression():
          break;
        case ListLiteralExpression(:final elements):
          for (final el in elements) {
            visitExpr(el, scopeVars);
          }
        case VariableExpression(:final name):
          if (!scopeVars.contains(name)) {
            errors.add(
              TemplateError(
                message: 'Undefined variable "$name"',
                code: TemplateErrorCode.resolveError,
              ),
            );
          }
        case PropertyAccessExpression(:final target):
          visitExpr(target, scopeVars);
        case IndexAccessExpression(:final target, :final index):
          visitExpr(target, scopeVars);
          visitExpr(index, scopeVars);
        case UnaryOpExpression(:final operand):
          visitExpr(operand, scopeVars);
        case BinaryOpExpression(:final left, :final right):
          visitExpr(left, scopeVars);
          visitExpr(right, scopeVars);
      }
    }

    void visitNodes(List<KnapNode> nodes, Set<String> scopeVars) {
      for (final node in nodes) {
        switch (node) {
          case TextNode():
            break;
          case VariableNode(:final expression):
            visitExpr(expression, scopeVars);
          case IfNode(
              :final condition,
              :final thenBranch,
              :final elifBranches,
              :final elseBranch
            ):
            visitExpr(condition, scopeVars);
            visitNodes(thenBranch, {...scopeVars});
            for (final elif in elifBranches) {
              visitExpr(elif.condition, scopeVars);
              visitNodes(elif.body, {...scopeVars});
            }
            visitNodes(elseBranch, {...scopeVars});
          case ForNode(
              :final variableName,
              :final collection,
              :final body,
              :final elseBody
            ):
            visitExpr(collection, scopeVars);
            visitNodes(
              body,
              {...scopeVars, variableName, '${variableName}_index'},
            );
            visitNodes(elseBody, {...scopeVars});
          case SetNode(:final name, :final value):
            visitExpr(value, scopeVars);
            scopeVars.add(name);
        }
      }
    }

    visitNodes(ast, defined);
    return errors;
  }
}
