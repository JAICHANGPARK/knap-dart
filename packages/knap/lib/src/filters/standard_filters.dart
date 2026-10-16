import 'collection_filters.dart';
import 'date_filters.dart';
import 'filter.dart';
import 'html_filters.dart';
import 'math_filters.dart';
import 'string_filters.dart';
import 'yaml_filters.dart';

export 'collection_filters.dart';
export 'date_filters.dart';
export 'math_filters.dart';
export 'string_filters.dart';
export 'yaml_filters.dart';

/// The built-in library of standard string, collection, math, date, and utility filters.
///
/// Combines string casing and manipulation ([stringFilters]),
/// collection transforms ([collectionFilters]),
/// date formatting ([dateFilters]),
/// math and number operations ([mathFilters]),
/// and YAML/JSON serialization ([yamlFilters]):
///
/// ```dart
/// final names = standardFilters['map']!(
///   [
///     {'name': 'Alice'},
///     {'name': 'Bob'},
///   ],
///   ['item => item.name'],
/// );
/// // ['Alice', 'Bob']
/// ```
final Map<String, KnapFilter> standardFilters = {
  ...stringFilters,
  ...collectionFilters,
  ...dateFilters,
  ...mathFilters,
  ...yamlFilters,
  'html_to_json': htmlToJsonFilter,
};
