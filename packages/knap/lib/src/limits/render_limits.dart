import '../errors/exceptions.dart';
import '../tokens/token.dart';

/// Resource and complexity limits enforced during template parsing and rendering.
///
/// Configure custom limits to guard against untrusted or overly complex
/// templates:
///
/// ```dart
/// final engine = KnapEngine.standard(
///   limits: const RenderLimits(
///     maxTemplateLength: 50000,
///     maxOperations: 5000,
///     maxDepth: 32,
///   ),
/// );
/// ```
class RenderLimits {
  /// Maximum allowed character length of the input template string.
  final int maxTemplateLength;

  /// Maximum allowed character length of the rendered output string.
  final int maxOutputLength;

  /// Maximum allowed serialized size of any evaluated value.
  final int maxValueLength;

  /// Maximum number of AST evaluation and loop steps permitted in a single render.
  final int maxOperations;

  /// Maximum AST nesting and object traversal depth permitted (1 to 256).
  final int maxDepth;

  /// Whether regular expression patterns are permitted in filters like `replace` and `split`.
  final bool allowRegex;

  /// Creates a [RenderLimits] configuration with optional overrides.
  const RenderLimits({
    this.maxTemplateLength = 1000000,
    this.maxOutputLength = 5000000,
    this.maxValueLength = 5000000,
    this.maxOperations = 100000,
    this.maxDepth = 100,
    this.allowRegex = true,
  });

  /// Validates that all configured limits are positive safe integers and [maxDepth] is at most `256`.
  void validate() {
    if (maxTemplateLength < 1) {
      throw const KnapLimitException('Invalid maxTemplateLength limit');
    }
    if (maxOutputLength < 1) {
      throw const KnapLimitException('Invalid maxOutputLength limit');
    }
    if (maxValueLength < 1) {
      throw const KnapLimitException('Invalid maxValueLength limit');
    }
    if (maxOperations < 1) {
      throw const KnapLimitException('Invalid maxOperations limit');
    }
    if (maxDepth < 1 || maxDepth > 256) {
      throw const KnapLimitException('Invalid maxDepth limit');
    }
  }
}

/// Default safety limits matching upstream `obsidianmd/knap`.
const RenderLimits defaultRenderLimits = RenderLimits();

/// Tracks operation count, output length, and value complexity during a single render pass.
class RenderBudget {
  /// The active limits enforced by this budget.
  final RenderLimits limits;
  int _operations = 0;

  /// Creates a [RenderBudget] enforcing [limits].
  RenderBudget([this.limits = defaultRenderLimits]) {
    limits.validate();
  }

  /// Records a single evaluation step and throws [KnapLimitException] if `maxOperations` is exceeded.
  void step([SourceLocation? location]) {
    if (++_operations > limits.maxOperations) {
      throw KnapLimitException('Template exceeded maxOperations', location);
    }
  }

  /// Verifies that the accumulated output [length] does not exceed `maxOutputLength`.
  void checkOutput(int length, [SourceLocation? location]) {
    if (length > limits.maxOutputLength) {
      throw KnapLimitException('Template exceeded maxOutputLength', location);
    }
  }

  /// Verifies that a string or buffer of [length] does not exceed `maxValueLength`.
  void checkLength(int length, [SourceLocation? location]) {
    if (length > limits.maxValueLength) {
      throw KnapLimitException('Template exceeded maxValueLength', location);
    }
  }

  /// Inspects an arbitrary [value] for depth, entry count, and total size against [limits].
  void checkValue(Object? value, [SourceLocation? location]) {
    final pending = <({Object? value, int depth})>[(value: value, depth: 0)];
    var size = 0;
    var entries = 0;

    while (pending.isNotEmpty) {
      step(location);
      final current = pending.removeLast();
      entries++;
      if (current.depth > limits.maxDepth) {
        throw KnapLimitException('Template exceeded maxDepth', location);
      }

      final val = current.value;
      if (val is String) {
        size += val.length;
      } else if (val is List) {
        for (final item in val) {
          size += 4;
          if (pending.length + entries >= limits.maxOperations) {
            throw KnapLimitException('Template exceeded maxOperations', location);
          }
          pending.add((value: item, depth: current.depth + 1));
        }
      } else if (val is Map) {
        for (final entry in val.entries) {
          size += entry.key.toString().length + 4;
          if (pending.length + entries >= limits.maxOperations) {
            throw KnapLimitException('Template exceeded maxOperations', location);
          }
          pending.add((value: entry.value, depth: current.depth + 1));
        }
      } else {
        size += 8;
      }

      if (size > limits.maxValueLength) {
        throw KnapLimitException('Template exceeded maxValueLength', location);
      }
    }
  }
}
