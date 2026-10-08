import 'dart:convert';
import 'filter.dart';
import 'standard_filters.dart';

Map<String, String> _parseAttributes(String rawAttrs) {
  final attrs = <String, String>{};
  final regex = RegExp(
    r'''([a-zA-Z0-9_:-]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?''',
  );
  for (final match in regex.allMatches(rawAttrs)) {
    final name = match.group(1)!;
    final val = match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
    attrs[name] = val;
  }
  return attrs;
}

const Set<String> _voidTags = {
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'param',
  'source',
  'track',
  'wbr',
};

List<Map<String, Object?>> _parseHtmlNodes(String html) {
  final rootChildren = <Map<String, Object?>>[];
  final stack = <Map<String, Object?>>[];

  void addNode(Map<String, Object?> node) {
    if (stack.isEmpty) {
      rootChildren.add(node);
    } else {
      final parent = stack.last;
      final children =
          (parent['children'] as List<Map<String, Object?>>?) ??
          <Map<String, Object?>>[];
      parent['children'] = children;
      children.add(node);
    }
  }

  final cleaned = html.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  final tokenRegex = RegExp(r'<(/?)([a-zA-Z0-9-]+)([^>]*)>|([^<]+)');

  for (final match in tokenRegex.allMatches(cleaned)) {
    final textPart = match.group(4);
    if (textPart != null) {
      final trimmed = textPart.trim();
      if (trimmed.isNotEmpty) {
        addNode({'type': 'text', 'content': trimmed});
      }
      continue;
    }

    final isClosing = match.group(1) == '/';
    final tag = match.group(2)!.toLowerCase();
    final rawAttrs = match.group(3) ?? '';

    if (isClosing) {
      if (stack.isNotEmpty && stack.last['tag'] == tag) {
        stack.removeLast();
      }
      continue;
    }

    final selfClosing =
        rawAttrs.trimRight().endsWith('/') || _voidTags.contains(tag);
    final attrSlice = rawAttrs.trimRight().endsWith('/')
        ? rawAttrs.substring(0, rawAttrs.lastIndexOf('/'))
        : rawAttrs;
    final attrs = _parseAttributes(attrSlice);

    final element = <String, Object?>{
      'type': 'element',
      'tag': tag,
      if (attrs.isNotEmpty) 'attributes': attrs,
    };

    addNode(element);
    if (!selfClosing) {
      stack.add(element);
    }
  }

  return rootChildren;
}

/// Converts an HTML string into a JSON tree of `{ type: 'element' | 'text', ... }` objects.
String htmlToJsonFilter(Object? val, List<Object?> args) {
  final input = val?.toString() ?? '';
  if (input.trim().isEmpty) return '[]';
  final nodes = _parseHtmlNodes(input);
  final result = nodes.length == 1 ? nodes.first : nodes;
  return jsonEncode(result);
}

/// Filters that operate on HTML fragments (`html_to_json` and `remove_html`), matching upstream `htmlFilters`.
final Map<String, KnapFilter> htmlFilters = {
  'html_to_json': htmlToJsonFilter,
  'remove_html': (val, args) => standardFilters['remove_html']!(val, args),
};
