## 2026.10.16

- Upgraded dependency to `knap ^2026.10.16` featuring 100% upstream `obsidianmd/knap` test suite passing conformance (188/188 fixtures).
- Full 100.00% line test coverage maintained across all controllers and widgets.
- 0 analyzer issues (`flutter analyze` clean).

## 2026.10.9

- Updated dependency to `knap ^2026.10.9` with full upstream `obsidianmd/knap` parity (91 built-in filters, `RenderLimits`, and diagnostics APIs).
- Achieved **100.00% line test coverage** across all controllers and widgets.
- Added Effective Dart (`///`) API documentation and code examples for `KnapTemplateController`, `KnapBuilder`, and `KnapMarkdownView`.

## 2026.9.26

- Updated dependency to `knap ^2026.9.26`.
- Support for new operators (`??`, `contains`, `elseif`), multi-word attributes, and 15+ new built-in filters.

## 2026.9.25

- Initial release of Flutter widgets for the Knap template engine.
- **`KnapMarkdownView`**: Direct rendering of Knap templates into styled, selectable Markdown widgets via `flutter_markdown`.
- **`KnapBuilder`**: Flexible builder widget responding to template compilation and execution state.
- **`KnapTemplateController`**: Reactive ChangeNotifier for managing template inputs, data sources, rendered output, and syntax error states.
- Support for inline visual syntax error diagnostics with monospace reporting.
