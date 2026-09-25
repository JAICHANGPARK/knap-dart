import 'package:flutter/foundation.dart';
import 'package:knap/knap.dart';

class KnapTemplateController extends ChangeNotifier {
  final KnapEngine engine;

  String _template;
  Map<String, Object?> _data;

  String _output = '';
  KnapException? _error;

  KnapTemplateController({
    String initialTemplate = '',
    Map<String, Object?>? initialData,
    KnapEngine? engine,
  })  : _template = initialTemplate,
        _data = initialData ?? {},
        engine = engine ?? KnapEngine.standard() {
    _render();
  }

  String get template => _template;
  set template(String newTemplate) {
    if (_template != newTemplate) {
      _template = newTemplate;
      _render();
    }
  }

  Map<String, Object?> get data => _data;
  set data(Map<String, Object?> newData) {
    _data = newData;
    _render();
  }

  String get output => _output;
  KnapException? get error => _error;
  bool get hasError => _error != null;

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
