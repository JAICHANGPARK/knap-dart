import 'package:flutter/foundation.dart';
import 'package:knap/knap.dart';

/// Manages template state and reactive re-rendering for Knap templates.
///
/// Holds the template string, evaluation data context, and the latest
/// rendered markdown output or evaluation error. Listeners are notified
/// whenever the template, data, or output changes.
class KnapTemplateController extends ChangeNotifier {
  /// The template engine used to evaluate and render templates.
  final KnapEngine engine;

  String _template;
  Map<String, Object?> _data;

  String _output = '';
  KnapException? _error;

  /// Creates a template controller.
  ///
  /// If [initialTemplate] is provided, it is rendered immediately with [initialData].
  /// If [engine] is not supplied, [KnapEngine.standard] is used by default.
  KnapTemplateController({
    String initialTemplate = '',
    Map<String, Object?>? initialData,
    KnapEngine? engine,
  })  : _template = initialTemplate,
        _data = initialData ?? {},
        engine = engine ?? KnapEngine.standard() {
    _render();
  }

  /// The active template string.
  ///
  /// Setting a new template string triggers re-rendering and notifies listeners.
  String get template => _template;
  set template(String newTemplate) {
    if (_template != newTemplate) {
      _template = newTemplate;
      _render();
    }
  }

  /// The data context map supplied to the template engine.
  ///
  /// Setting new data triggers re-rendering and notifies listeners.
  Map<String, Object?> get data => _data;
  set data(Map<String, Object?> newData) {
    _data = newData;
    _render();
  }

  /// The most recently rendered output string.
  String get output => _output;

  /// The exception thrown during the last render pass, or `null` if successful.
  KnapException? get error => _error;

  /// Whether the last render pass produced an error.
  bool get hasError => _error != null;

  /// Updates both [template] and [data] in a single atomic render pass.
  ///
  /// Listeners will be notified once after the render completes if either
  /// property changed.
  void update({String? template, Map<String, Object?>? data}) {
    var changed = false;
    if (template != null && template != _template) {
      _template = template;
      changed = true;
    }
    if (data != null) {
      _data = data;
      changed = true;
    }
    if (changed) {
      _render();
    }
  }

  void _render() {
    try {
      _output = engine.render(_template, data: _data);
      _error = null;
    } on KnapException catch (e) {
      _error = e;
    } catch (e) {
      _error = KnapEvaluationException(e.toString());
    }
    notifyListeners();
  }
}
