import 'package:flutter/widgets.dart';
import 'package:knap/knap.dart';
import '../controllers/knap_controller.dart';

/// Signature for building a widget based on rendered markdown output or an error.
///
/// [context] is the build context.
/// [renderedMarkdown] is the formatted output string from the template engine.
/// [error] is non-null if a syntax or evaluation exception occurred.
typedef KnapWidgetBuilder = Widget Function(
  BuildContext context,
  String renderedMarkdown,
  KnapException? error,
);

/// A widget that reactively renders a Knap template and builds its child UI.
///
/// Either [controller] or [template] must be provided. If a [controller] is passed,
/// it will be listened to for changes. Otherwise, an internal [KnapTemplateController]
/// is created and managed automatically.
class KnapBuilder extends StatefulWidget {
  /// The template string to evaluate when managing an internal controller.
  final String? template;

  /// The variable data context map passed to the template.
  final Map<String, Object?>? data;

  /// The custom engine instance, or standard engine if `null`.
  final KnapEngine? engine;

  /// An optional external controller to manage template state and rendering.
  final KnapTemplateController? controller;

  /// The builder callback invoked with the current markdown output or error.
  final KnapWidgetBuilder builder;

  /// Creates a reactive template builder widget.
  ///
  /// Either [controller] or [template] must be provided.
  const KnapBuilder({
    super.key,
    this.template,
    this.data,
    this.engine,
    this.controller,
    required this.builder,
  }) : assert(
          controller != null || template != null,
          'Either controller or template must be provided to KnapBuilder',
        );

  @override
  State<KnapBuilder> createState() => _KnapBuilderState();
}

class _KnapBuilderState extends State<KnapBuilder> {
  late KnapTemplateController _controller;
  bool _internalController = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (widget.controller != null) {
      _controller = widget.controller!;
      _internalController = false;
    } else {
      _controller = KnapTemplateController(
        initialTemplate: widget.template ?? '',
        initialData: widget.data,
        engine: widget.engine,
      );
      _internalController = true;
    }
  }

  @override
  void didUpdateWidget(KnapBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (_internalController) {
        _controller.dispose();
      }
      _initController();
    } else if (_internalController) {
      _controller.update(
        template: widget.template,
        data: widget.data,
      );
    }
  }

  @override
  void dispose() {
    if (_internalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return widget.builder(
          context,
          _controller.output,
          _controller.error,
        );
      },
    );
  }
}
