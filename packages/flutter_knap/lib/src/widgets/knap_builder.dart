import 'package:flutter/widgets.dart';
import 'package:knap/knap.dart';
import '../controllers/knap_controller.dart';

typedef KnapWidgetBuilder = Widget Function(
  BuildContext context,
  String renderedMarkdown,
  KnapException? error,
);

class KnapBuilder extends StatefulWidget {
  final String? template;
  final Map<String, Object?>? data;
  final KnapEngine? engine;
  final KnapTemplateController? controller;
  final KnapWidgetBuilder builder;

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
