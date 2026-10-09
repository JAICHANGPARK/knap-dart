# Changelog

All notable changes to this project will be documented in this file.

## [2026.10.9] - 2026-10-09

### Knap (`packages/knap`)
- Achieved 100% feature parity with upstream `obsidianmd/knap` (91 built-in filters).
- Added 6 new filters: `embed`, `table_pretty`, `truncatewords`, `yaml_property`, `stripmd`, and `html_to_json` (plus `htmlFilters`).
- Added full upstream parameter support for `bold:_`, `italic:_`, `list` (`numbered`, `task`, `numbered-task`), `yaml:flow` and block collections, `safe_name` (`windows`, `mac`, `linux`), `map` arrow expressions (`item => ...`), `sort` by property/direction, `replace` regex literals, `footnote` maps/lists, `callout` fold states, and dynamic backtick fences in `code`.
- Added symbolic logical operators (`&&`, `||`), arrow token (`=>`), negative numbers, CSS selector literals (`selector:`, `selectorHtml:`), parenthesized filter arguments, `{{key}}`-wrapped variable lookups, `variableResolver` / `asyncVariableResolver`, JSON array strings in `for` loops, and `<iterator>_index` loop variables.
- Added `RenderLimits`, `RenderBudget`, `validate`, `validateFilters`, `validateVariables`, `renderWithDiagnostics`, `renderOrThrow`, and `applyFiltersWithRegistry`.
- Expanded CLI (`bin/knap.dart`) with `validate`, `batch` (including RFC 4180 `parseCsv`), and `help` subcommands.
- Achieved **100.00% line coverage** (2,219/2,219 lines) and added Effective Dart API doc examples.

### Flutter Knap (`packages/flutter_knap`)
- Upgraded to `knap ^2026.10.9`.
- Achieved **100.00% line coverage** (92/92 lines) and added Effective Dart API doc examples.

## [2026.9.26] - 2026-09-26

### Knap (`packages/knap`)
- Added `??`, `contains`, `elseif`, multi-word attributes, colon-chained filter arguments, and 15+ built-in Web Clipper, Markdown, collection, and math filters.

### Flutter Knap (`packages/flutter_knap`)
- Upgraded to `knap ^2026.9.26`.

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
