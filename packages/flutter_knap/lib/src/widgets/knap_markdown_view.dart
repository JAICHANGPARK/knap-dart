import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:knap/knap.dart';
import '../controllers/knap_controller.dart';
import 'knap_builder.dart';

/// A high-level Flutter widget that evaluates a Knap template and renders
/// the resulting markdown directly to the screen using `flutter_markdown`.
///
/// If an evaluation error occurs, an error card is shown by default or custom
/// UI is rendered using [errorBuilder].
class KnapMarkdownView extends StatelessWidget {
  /// The template string to evaluate when managing an internal controller.
  final String? template;

  /// The variable data context map passed to the template.
  final Map<String, Object?>? data;

  /// The custom engine instance, or standard engine if `null`.
  final KnapEngine? engine;

  /// An optional external controller to manage template state and rendering.
  final KnapTemplateController? controller;

  /// Whether the rendered markdown text is selectable by the user.
  final bool selectable;

  /// Optional styling options for the rendered markdown.
  final MarkdownStyleSheet? styleSheet;

  /// Optional custom builder to display when a [KnapException] occurs.
  final Widget Function(BuildContext context, KnapException error)? errorBuilder;

  /// Creates a markdown view widget that dynamically renders a Knap template.
  ///
  /// Either [controller] or [template] must be provided.
  const KnapMarkdownView({
    super.key,
    this.template,
    this.data,
    this.engine,
    this.controller,
    this.selectable = true,
    this.styleSheet,
    this.errorBuilder,
  }) : assert(
          controller != null || template != null,
          'Either controller or template must be provided',
        );

  @override
  Widget build(BuildContext context) {
    return KnapBuilder(
      template: template,
      data: data,
      engine: engine,
      controller: controller,
      builder: (context, markdownText, error) {
        if (error != null) {
          if (errorBuilder != null) {
            return errorBuilder!(context, error);
          }
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error.toString(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.red.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return MarkdownBody(
          data: markdownText,
          selectable: selectable,
          styleSheet: styleSheet,
        );
      },
    );
  }
}
