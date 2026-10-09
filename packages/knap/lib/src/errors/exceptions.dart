/// @docImport '../knap_engine.dart';
/// @docImport '../limits/render_limits.dart';
library;

import '../tokens/token.dart';

/// Machine-readable error codes emitted during template validation or rendering.
enum TemplateErrorCode {
  /// Template syntax or grammar error.
  parseError('PARSE_ERROR'),

  /// Referenced filter is not registered in the active engine.
  unknownFilter('UNKNOWN_FILTER'),

  /// Filter arguments failed static or runtime validation.
  invalidFilterArguments('INVALID_FILTER_ARGUMENTS'),

  /// Custom variable resolver failed.
  resolveError('RESOLVE_ERROR'),

  /// Filter threw an exception during execution.
  filterError('FILTER_ERROR'),

  /// Resource or complexity limit exceeded ([RenderLimits]).
  limitExceeded('LIMIT_EXCEEDED'),

  /// General runtime evaluation error.
  renderError('RENDER_ERROR');

  /// The string code matching upstream `obsidianmd/knap`.
  final String code;

  const TemplateErrorCode(this.code);
}

/// Machine-readable warning codes emitted by filters during template rendering.
enum TemplateWarningCode {
  /// Input value could not be parsed as expected by the filter.
  invalidFilterInput('INVALID_FILTER_INPUT'),

  /// General non-fatal filter warning.
  filterWarning('FILTER_WARNING');

  /// The string code matching upstream `obsidianmd/knap`.
  final String code;

  const TemplateWarningCode(this.code);
}

/// A structured diagnostic error reported during template parsing, validation, or rendering.
class TemplateError {
  /// Human-readable description of the error.
  final String message;

  /// 1-based line number where the error occurred.
  final int line;

  /// 1-based column number where the error occurred.
  final int column;

  /// Machine-readable category code for this error.
  final TemplateErrorCode code;

  /// Creates a [TemplateError] with [message], [line], [column], and [code].
  const TemplateError({
    required this.message,
    this.line = 1,
    this.column = 1,
    this.code = TemplateErrorCode.renderError,
  });

  @override
  String toString() => '[${code.code}] $line:$column: $message';
}

/// A non-fatal warning reported by a filter during template rendering.
class TemplateWarning {
  /// Human-readable description of the warning.
  final String message;

  /// 1-based line number where the warning originated.
  final int line;

  /// 1-based column number where the warning originated.
  final int column;

  /// Machine-readable category code for this warning.
  final TemplateWarningCode code;

  /// Name of the filter that reported the warning.
  final String filter;

  /// Creates a [TemplateWarning] with [message], [filter], and optional location and [code].
  const TemplateWarning({
    required this.message,
    required this.filter,
    this.line = 1,
    this.column = 1,
    this.code = TemplateWarningCode.filterWarning,
  });

  @override
  String toString() => '[${code.code}] ($filter) $line:$column: $message';
}

/// The non-throwing result of rendering a Knap template, containing output, errors, and warnings.
///
/// Returned by [KnapEngine.renderWithDiagnostics]:
///
/// ```dart
/// final engine = KnapEngine.standard();
/// final result = engine.renderWithDiagnostics(
///   'Hello {{ name | upper }}',
///   data: {'name': 'world'},
/// );
/// if (result.isSuccess) {
///   print(result.output); // Hello WORLD
/// }
/// ```
class TemplateResult {
  /// The rendered Markdown output string, or an empty string if fatal errors occurred.
  final String output;

  /// Any syntax, validation, limit, or runtime errors encountered.
  final List<TemplateError> errors;

  /// Any non-fatal filter warnings recorded during rendering.
  final List<TemplateWarning> warnings;

  /// Creates a [TemplateResult] with [output], [errors], and [warnings].
  const TemplateResult({
    required this.output,
    this.errors = const [],
    this.warnings = const [],
  });

  /// Whether the template rendered without any [errors].
  bool get isSuccess => errors.isEmpty;
}

/// Base exception class for all Knap template errors.
///
/// Subclasses include [KnapSyntaxException], [KnapEvaluationException], and
/// [KnapLimitException].
abstract class KnapException implements Exception {
  /// The descriptive error message.
  final String message;

  /// The location in the template source where the error occurred, if available.
  final SourceLocation? location;

  /// The machine-readable error code associated with this exception.
  final TemplateErrorCode code;

  /// Creates a [KnapException] with a [message], optional [location], and [code].
  const KnapException(
    this.message, [
    this.location,
    this.code = TemplateErrorCode.renderError,
  ]);

  @override
  String toString() {
    if (location != null) {
      return 'KnapError at line ${location!.line}, column ${location!.column}: $message';
    }
    return 'KnapError: $message';
  }
}

/// Thrown when a template contains invalid grammar, unclosed tags, or malformed syntax.
class KnapSyntaxException extends KnapException {
  /// Creates a [KnapSyntaxException] with a [message] and optional [location].
  const KnapSyntaxException(
    String message, [
    SourceLocation? location,
  ]) : super(message, location, TemplateErrorCode.parseError);
}

/// Thrown when a template fails during evaluation or filter execution.
class KnapEvaluationException extends KnapException {
  /// Creates a [KnapEvaluationException] with a [message], optional [location], and [code].
  const KnapEvaluationException(
    super.message, [
    super.location,
    super.code = TemplateErrorCode.renderError,
  ]);
}

/// Thrown when a template exceeds a configured [RenderLimits] threshold.
class KnapLimitException extends KnapException {
  /// Creates a [KnapLimitException] with a [message] and optional [location].
  const KnapLimitException(
    String message, [
    SourceLocation? location,
  ]) : super(message, location, TemplateErrorCode.limitExceeded);
}
