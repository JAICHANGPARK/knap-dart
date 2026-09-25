import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:knap/knap.dart';
import '../controllers/knap_controller.dart';
import 'knap_builder.dart';

class KnapMarkdownView extends StatelessWidget {
  final String? template;
  final Map<String, Object?>? data;
  final KnapEngine? engine;
  final KnapTemplateController? controller;
  final bool selectable;
  final MarkdownStyleSheet? styleSheet;
  final Widget Function(BuildContext context, KnapException error)? errorBuilder;

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
