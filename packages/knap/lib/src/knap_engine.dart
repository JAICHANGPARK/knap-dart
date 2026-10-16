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

/// Applies a pipe-separated [filterChain] to [value] using [registry].
///
/// Useful when transforming a value through Knap filters outside a full
/// template string:
///
/// ```dart
/// final engine = KnapEngine.standard();
/// final slug = applyFiltersWithRegistry(
///   '  Hello World!  ',
///   'trim | slug',
///   engine.filterRegistry,
/// );
/// print(slug); // hello-world
/// ```
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
  return evaluator.evaluateExpression(varNode.expression);
}

/// A compiled, reusable Knap template holding the parsed abstract syntax tree ([ast]).
///
/// Compile a template once via [KnapEngine.compile] and render it across
/// multiple data payloads without re-tokenizing or re-parsing:
///
/// ```dart
/// final engine = KnapEngine.standard();
/// final template = engine.compile('Hello, {{ name | capitalize }}!');
///
/// print(template.render(data: {'name': 'alice'}, filters: engine.filterRegistry));
/// print(template.render(data: {'name': 'bob'}, filters: engine.filterRegistry));
/// ```
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
///
/// Use [KnapEngine.standard] to create an instance pre-configured with all
/// built-in standard, Markdown, and HTML filters:
///
/// ```dart
/// final engine = KnapEngine.standard();
/// final output = engine.render(
///   '{% for item in items %}- {{ item | bold }}\n{% endfor %}',
///   data: {
///     'items': ['First', 'Second'],
///   },
/// );
/// ```
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

  /// Creates an engine pre-configured with all [standardFilters], [markdownFilters], and [htmlFilters].
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
  ///
  /// Throws a [KnapSyntaxException] if the template has malformed syntax, or a
  /// [KnapLimitException] if [source] exceeds [RenderLimits.maxTemplateLength].
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
  ///
  /// ```dart
  /// final engine = KnapEngine.standard();
  /// final result = engine.render(
  ///   '{{ title | h1 }}',
  ///   data: {'title': 'Release Notes'},
  /// );
  /// // '# Release Notes'
  /// ```
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
  ///
  /// Supports asynchronous filters registered via [FilterRegistry.registerAsync]
  /// as well as [asyncVariableResolver].
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
  ///
  /// Captures any [KnapException] or unknown filter references into
  /// [TemplateResult.errors]:
  ///
  /// ```dart
  /// final engine = KnapEngine.standard();
  /// final result = engine.renderWithDiagnostics('{{ x | unknown_filter }}');
  /// print(result.isSuccess); // false
  /// print(result.errors.first.code); // TemplateErrorCode.unknownFilter
  /// ```
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
      final context = KnapContext(
        variables: data,
        filterRegistry: filterRegistry,
        variableResolver: variableResolver,
        lenient: filterErrors.isNotEmpty,
      );
      final evaluator = KnapEvaluator(context, limits: effectiveLimits);
      final output = evaluator.evaluate(template.ast);
      return TemplateResult(
        output: output,
        errors: filterErrors,
        warnings: List.unmodifiable(context.warnings),
      );
    } on KnapSyntaxException catch (e) {
      return TemplateResult(
        output: '',
        errors: [
          TemplateError(
            message: e.message,
            line: e.location?.line ?? 1,
            column: e.location?.column ?? 1,
            code: TemplateErrorCode.parseError,
          ),
        ],
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
  ///
  /// Returns an empty list if the template is valid:
  ///
  /// ```dart
  /// final engine = KnapEngine.standard();
  /// final errors = engine.validate('Hello {{ name | upper }}');
  /// assert(errors.isEmpty);
  /// ```
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

    void visitExpr(Expression expr) {
      switch (expr) {
        case LiteralExpression():
          break;
        case ListLiteralExpression(:final elements):
          for (final el in elements) {
            visitExpr(el);
          }
        case VariableExpression():
          break;
        case PropertyAccessExpression(:final target):
          visitExpr(target);
        case IndexAccessExpression(:final target, :final index):
          visitExpr(target);
          visitExpr(index);
        case UnaryOpExpression(:final operand):
          visitExpr(operand);
        case BinaryOpExpression(:final left, :final right):
          visitExpr(left);
          visitExpr(right);
        case FilterExpression(:final target, :final filter):
          if (!filterRegistry.has(filter.name)) {
            errors.add(
              TemplateError(
                message: 'Unknown filter "${filter.name}"',
                code: TemplateErrorCode.unknownFilter,
              ),
            );
          }
          visitExpr(target);
          for (final arg in filter.arguments) {
            visitExpr(arg);
          }
      }
    }

    void visitNodes(List<KnapNode> nodes) {
      for (final node in nodes) {
        switch (node) {
          case TextNode():
            break;
          case VariableNode(:final expression, :final filters):
            visitExpr(expression);
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
              :final condition,
              :final thenBranch,
              :final elifBranches,
              :final elseBranch
            ):
            visitExpr(condition);
            visitNodes(thenBranch);
            for (final elif in elifBranches) {
              visitExpr(elif.condition);
              visitNodes(elif.body);
            }
            visitNodes(elseBranch);
          case ForNode(:final collection, :final body, :final elseBody):
            visitExpr(collection);
            visitNodes(body);
            visitNodes(elseBody);
          case SetNode(:final value):
            visitExpr(value);
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
        case FilterExpression(:final target, :final filter):
          visitExpr(target, scopeVars);
          for (final arg in filter.arguments) {
            visitExpr(arg, scopeVars);
          }
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
