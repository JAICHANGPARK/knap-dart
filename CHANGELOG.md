# Changelog

All notable changes to this project will be documented in this file.

## [2026.9.25] - 2026-09-25

### Knap (`packages/knap`)
- Initial release of Knap for Dart.
- AST-based parser and interpreter with zero `eval` or arbitrary code execution.
- Liquid/Jinja-compatible templating syntax (`{{ ... }}`, `{% ... %}`).
- Whitespace trimming control (`{{- -}}`, `{%- -%}`).
- Variable and property/index expressions with `{% set name = expr %}` assignment.
- Template comments (`{# ... #}` and `{#- ... -#}`).
- Control flow: `if / elif / else` and `for ... in ... else` with loop metadata (`loop.index`, `loop.index0`, `loop.revindex`, `loop.revindex0`, `loop.first`, `loop.last`, `loop.length`).
- Markdown filters: `wikilink`, `link`, `list`, `task_list`, `table`, `callout`, `quote`, `tag`, `codeblock`, `inline_code`, `bold`, `italic`, `strikethrough`, `escape_md`.
- Standard string & collection filters: `trim`, `upper`, `lower`, `capitalize`, `title`, `slug`, `replace`, `truncate`, `default`, `first`, `last`, `join`, `sort`, `reverse`, `slice`, `length`, `merge`, `unique`, `json`, `yaml`, `hard_break`.
- Date filters: `date`, `date_modify`.
- Case conversion filters: `snake`, `camel`, `kebab`, `pascal`.
- Asynchronous evaluation support (`renderAsync()`) for external data/API-backed custom filters.
- Built-in CLI executable (`dart run knap render`).

### Flutter Knap (`packages/flutter_knap`)
- Initial release of Flutter extensions for Knap.
- `KnapMarkdownView` with `flutter_markdown` integration.
- `KnapBuilder` for custom reactive rendering and syntax error handling.
- `KnapTemplateController` for reactive state management and live playground editors.
