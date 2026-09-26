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
