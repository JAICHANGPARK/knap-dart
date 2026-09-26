import '../tokens/token.dart';

/// Base exception class for all Knap template errors.
abstract class KnapException implements Exception {
  /// The descriptive error message.
  final String message;

  /// The location in the template source where the error occurred, if available.
  final SourceLocation? location;

  /// Creates a [KnapException] with a [message] and optional [location].
  const KnapException(this.message, [this.location]);

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
  const KnapSyntaxException(super.message, [super.location]);
}

/// Thrown when a template fails during evaluation or filter execution.
class KnapEvaluationException extends KnapException {
  /// Creates a [KnapEvaluationException] with a [message] and optional [location].
  const KnapEvaluationException(super.message, [super.location]);
}
