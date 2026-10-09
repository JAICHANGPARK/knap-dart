## 2026.10.9

- **100% Upstream (`obsidianmd/knap`) Parity**:
  - **6 New Built-in Filters**: `embed` (`![[target|alias]]`), `table_pretty` (column-width padded Markdown tables), `truncatewords`, `yaml_property`, `stripmd` alias, and `html_to_json` (plus exported `htmlFilters` map).
  - **Filter Parameter Enhancements**:
    - `bold:_` and `italic:_` underscore style markers.
    - `list:numbered`, `list:task`, `list:numbered-task`, and nested array indentation.
    - `yaml` multi-line block rendering for collections and `yaml:flow` inline mode.
    - `safe_name:windows` (including reserved device names), `safe_name:mac`, and `safe_name:linux`.
    - `map` arrow expressions (`map:item => item.name`, `map:x => "${x.title}"`, object projections).
    - `sort` by object property and direction (`sort:"age":"desc"`).
    - `replace` regular expression literals (`replace:"/\\d+/g":"#"`) and multi-pair replacements.
    - `footnote` definitions from `Map` and `List` values.
    - `callout` fold state parameter (`true` for `-`, `false` for `+`).
    - Auto-incrementing backtick fences in `code` and `code_block` when content contains backticks.
  - **Lexer, Parser & Runtime Enhancements**:
    - Symbolic logical operators (`&&`, `||`), arrow token (`=>`), negative numeric literals, and CSS selector literals (`selector:`, `selectorHtml:`).
    - Parenthesized filter arguments (`replace:(a ?? "x"):"y"`, `slice:(0, 5)`).
    - Support for `{{key}}`-wrapped data map keys, dynamic `variableResolver` / `asyncVariableResolver`, JSON array strings in `{% for %}`, and `<iterator>_index` loop variables.
  - **Resource Protection & Diagnostics API**:
    - Added `RenderLimits`, `defaultRenderLimits`, `RenderBudget`, and `KnapLimitException`.
    - Added `validate`, `validateFilters`, `validateVariables`, `renderWithDiagnostics` (`TemplateResult`), `renderOrThrow`, and `applyFiltersWithRegistry`.
  - **CLI Expansion (`bin/knap.dart`)**:
    - Added `knap validate`, `knap batch` (with RFC 4180 `parseCsv`), and `knap help` (`filters`, `syntax`, `examples`).
- **Quality & Documentation**:
  - Achieved **100.00% line test coverage** across all 14 library files.
  - Added Effective Dart (`///`) documentation comments with executable code examples across all public APIs.

## 2026.9.26

- **Upstream Parity & Operators**:
  - Added null coalescing operator `??` (`{{ title ?? fallback }}`).
  - Added `contains` operator for Lists, Strings, and Maps (`{% if tags contains "dart" %}`).
  - Added `elseif` keyword as alias for `elif`.
  - Added multi-word identifier support for Clipper attributes (e.g. `{{ First name | upper }}`).
  - Added colon-chained argument support for filters (e.g. `replace:"old":"new"`).
- **New Built-in Filters**:
  - Web Clipper & Filesystem: `safe_name`, `strip_tags` (`remove_html`, `remove_tags`).
  - Markdown: `strip_md`, `blockquote`, `image`, `footnote`, `fragment_link`.
  - Collections: `where`, `map`, `compact`, `split`.
  - Math & Numbers: `sum`, `round`, `number_format`.
  - Utilities: `duration`, `indent`, `encode_uri`, `decode_uri`, `parse_json`.

## 2026.9.25

- Initial release of Knap for Dart.
- **Security & Safety**: AST-based parser and interpreter with zero `eval` or arbitrary code execution.
- **Markdown-first Templating**:
  - Liquid/Jinja-compatible syntax (`{{ ... }}`, `{% ... %}`).
  - Whitespace trimming control (`{{- -}}`, `{%- -%}`).
  - Built-in Markdown filters: `wikilink`, `link`, `list`, `task_list`, `table`, `callout`, `quote`, `tag`, `codeblock`, `inline_code`, `bold`, `italic`, `strikethrough`, `escape_md`.
- **Logic & Flow Control**:
  - `if / elif / else` conditional branches.
  - `for ... in ... else` iterations with loop metadata (`loop.index`, `loop.index0`, `loop.revindex`, `loop.revindex0`, `loop.first`, `loop.last`, `loop.length`).
  - Variable assignment statements (`{% set name = expr %}`).
  - Comment tags (`{# comment #}`, `{#- comment -#}`).
- **Rich Standard Filters**:
  - String manipulation: `trim`, `upper`, `lower`, `capitalize`, `title`, `slug`, `replace`, `truncate`, `default`.
  - Case formatting: `snake`, `camel`, `kebab`, `pascal`.
  - Collection helpers: `first`, `last`, `join`, `sort`, `reverse`, `slice`, `length`, `merge`, `unique`.
  - Formatting & Data: `json`, `yaml`, `hard_break`.
  - Date helpers: `date`, `date_modify`.
- **Async Execution Support**: Synchronous (`render()`) and asynchronous (`renderAsync()`) evaluation with async custom filters.
- **Built-in CLI**: Standalone command-line tool `dart run knap render`.
