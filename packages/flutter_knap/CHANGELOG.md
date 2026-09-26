## 2026.9.26

- Updated dependency to `knap ^2026.9.26`.
- Support for new operators (`??`, `contains`, `elseif`), multi-word attributes, and 15+ new built-in filters.

## 2026.9.25

- Initial release of Flutter widgets for the Knap template engine.
- **`KnapMarkdownView`**: Direct rendering of Knap templates into styled, selectable Markdown widgets via `flutter_markdown`.
- **`KnapBuilder`**: Flexible builder widget responding to template compilation and execution state.
- **`KnapTemplateController`**: Reactive ChangeNotifier for managing template inputs, data sources, rendered output, and syntax error states.
- Support for inline visual syntax error diagnostics with monospace reporting.
