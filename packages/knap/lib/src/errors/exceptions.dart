import '../tokens/token.dart';

abstract class KnapException implements Exception {
  final String message;
  final SourceLocation? location;

  const KnapException(this.message, [this.location]);

  @override
  String toString() {
    if (location != null) {
      return 'KnapError at line ${location!.line}, column ${location!.column}: $message';
    }
    return 'KnapError: $message';
  }
}

class KnapSyntaxException extends KnapException {
  const KnapSyntaxException(super.message, [super.location]);
}

class KnapEvaluationException extends KnapException {
  const KnapEvaluationException(super.message, [super.location]);
}
