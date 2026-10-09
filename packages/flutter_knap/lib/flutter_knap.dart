/// Flutter widgets and reactive state management for the Knap Markdown template engine.
///
/// Use [KnapMarkdownView] for immediate Markdown rendering, or [KnapBuilder]
/// with [KnapTemplateController] for custom reactive UI:
///
/// @docImport 'src/controllers/knap_controller.dart';
/// @docImport 'src/widgets/knap_builder.dart';
/// @docImport 'src/widgets/knap_markdown_view.dart';
///
/// ```dart
/// import 'package:flutter_knap/flutter_knap.dart';
///
/// KnapMarkdownView(
///   template: '# {{ title }}\n{{ body | blockquote }}',
///   data: const {
///     'title': 'Daily Note',
///     'body': 'Captured with Flutter Knap.',
///   },
/// )
/// ```
library;

export 'package:knap/knap.dart';

export 'src/controllers/knap_controller.dart';
export 'src/widgets/knap_builder.dart';
export 'src/widgets/knap_markdown_view.dart';
