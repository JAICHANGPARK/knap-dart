import 'package:knap/knap.dart';
import 'package:test/test.dart';

void main() {
  group('Markdown Filters Complete Coverage', () {
    test('link and image filters', () {
      final link = standardFilters['link'] ?? markdownFilters['link']!;
      expect(link(null, []), '');
      expect(link('https://example.com', []), '[https://example.com](https://example.com)');
      expect(link('https://example.com', ['Example']), '[Example](https://example.com)');

      final image = markdownFilters['image']!;
      expect(image(null, []), '');
      expect(image('img.png', []), '![](img.png)');
      expect(image('img.png', ['Alt']), '![Alt](img.png)');
    });

    test('list and task_list filters', () {
      final list = markdownFilters['list']!;
      expect(list(null, []), '');
      expect(list([], []), '');
      expect(list(['A', 'B'], ['*']), '* A\n* B');
      expect(list('single', []), '- single');

      final taskList = markdownFilters['task_list']!;
      expect(taskList(null, []), '');
      expect(taskList([], []), '');
      expect(taskList('single', []), '- [ ] single');
      expect(
        taskList([
          {'title': 'Task 1', 'completed': true},
          {'name': 'Task 2', 'done': true},
          {'text': 'Task 3', 'checked': true},
          {'title': 'Task 4', 'completed': false},
          'Plain string task',
        ], []),
        '- [x] Task 1\n- [x] Task 2\n- [x] Task 3\n- [ ] Task 4\n- [ ] Plain string task',
      );
    });

    test('formatting and styling filters', () {
      final bold = markdownFilters['bold']!;
      expect(bold(null, []), '');
      expect(bold('text', []), '**text**');

      final italic = markdownFilters['italic']!;
      expect(italic(null, []), '');
      expect(italic('text', []), '*text*');

      final strike = markdownFilters['strike']!;
      expect(strike(null, []), '');
      expect(strike('text', []), '~~text~~');

      final inlineCode = markdownFilters['inline_code']!;
      expect(inlineCode(null, []), '');
      expect(inlineCode('val', []), '`val`');

      final codeblock = markdownFilters['codeblock']!;
      expect(codeblock('code', ['dart']), '```dart\ncode\n```');

      final tag = markdownFilters['tag']!;
      expect(tag(null, []), '');
      expect(tag('flutter', []), '#flutter');
      expect(tag('#dart', []), '#dart');

      final escapeMd = markdownFilters['escape_md']!;
      expect(escapeMd(r'Text with [brackets] and *stars* and \slashes!', []), r'Text with \[brackets\] and \*stars\* and \\slashes\!');

      final footnote = markdownFilters['footnote']!;
      expect(footnote(null, []), '');
      expect(footnote('1', []), '[^1]');

      final fragment = markdownFilters['fragment_link']!;
      expect(fragment(null, []), '');
      expect(fragment('My Section Name', []), '#my-section-name');
    });

    test('headings h1 through h6', () {
      expect(markdownFilters['h1']!('Title', []), '# Title');
      expect(markdownFilters['h2']!('Title', []), '## Title');
      expect(markdownFilters['h3']!('Title', []), '### Title');
      expect(markdownFilters['h4']!('Title', []), '#### Title');
      expect(markdownFilters['h5']!('Title', []), '##### Title');
      expect(markdownFilters['h6']!('Title', []), '###### Title');
    });

    test('highlight, hr, code, math, comment', () {
      final highlight = markdownFilters['highlight']!;
      expect(highlight(null, []), '');
      expect(highlight('alert', ['red']), '==🔴alert==');
      expect(highlight('warn', ['orange']), '==🟠warn==');
      expect(highlight('note', ['yellow']), '==🟡note==');
      expect(highlight('done', ['green']), '==🟢done==');
      expect(highlight('info', ['blue']), '==🔵info==');
      expect(highlight('special', ['purple']), '==🟣special==');
      expect(highlight('plain', []), '==plain==');

      final hr = markdownFilters['hr']!;
      expect(hr(null, []), '---');
      expect(hr('content', ['before']), '---\n\ncontent');
      expect(hr('content', ['both']), '---\n\ncontent\n\n---');
      expect(hr('content', ['after']), 'content\n\n---');

      final code = markdownFilters['code']!;
      expect(code('single', []), '`single`');
      expect(code('line1\nline2', []), '```\nline1\nline2\n```');
      expect(code('print()', ['dart']), '```dart\nprint()\n```');

      final codeBlock = markdownFilters['code_block']!;
      expect(codeBlock('code', []), '```\ncode\n```');

      final math = markdownFilters['math']!;
      expect(math('x^2', []), r'$x^2$');
      expect(math('x^2\n+ y^2', []), "\$\$\nx^2\n+ y^2\n\$\$");

      final mathBlock = markdownFilters['math_block']!;
      expect(mathBlock('E = mc^2', []), "\$\$\nE = mc^2\n\$\$");

      final comment = markdownFilters['comment']!;
      expect(comment('todo', []), '%%todo%%');
      expect(comment('multiline\ntodo', []), '%%\nmultiline\ntodo\n%%');
    });
  });

  group('Standard Filters Complete Coverage', () {
    test('date and date_modify with epoch timestamps and relative keywords', () {
      final date = standardFilters['date']!;
      expect(date(null, []), '');

      // Epoch seconds (< 10000000000)
      final dtSec = date(1700000000, ['YYYY-MM-DD']);
      expect(dtSec, isNotEmpty);

      // Epoch milliseconds (>= 10000000000)
      final dtMs = date(1700000000000, ['YYYY-MM-DD']);
      expect(dtMs, isNotEmpty);

      // 'now' and 'today'
      expect(date('now', ['YYYY']), DateTime.now().year.toString());
      expect(date('today', ['YYYY']), DateTime.now().year.toString());

      // DateTime instance directly
      final directDt = DateTime(2026, 9, 26, 12, 34, 56);
      expect(date(directDt, ['YYYY-YY-MM-DD-HH-mm-ss']), '2026-26-09-26-12-34-56');

      // Invalid date string
      expect(date('invalid-date', []), 'invalid-date');

      // date_modify
      final dateModify = standardFilters['date_modify']!;
      expect(dateModify(null, ['+1 day']), '');
      expect(dateModify('invalid', ['+1 day']), 'invalid');
      final modified = dateModify('2026-01-01', ['+2 days']);
      expect(modified, contains('2026-01-03'));
    });

    test('string case filters and null safety', () {
      expect(standardFilters['trim']!(null, []), '');
      expect(standardFilters['upper']!(null, []), '');
      expect(standardFilters['lower']!(null, []), '');
      expect(standardFilters['capitalize']!(null, []), '');
      expect(standardFilters['capitalize']!('', []), '');
      expect(standardFilters['title']!(null, []), '');
      expect(standardFilters['title']!('', []), '');
      expect(standardFilters['title']!('hello  world', []), 'Hello  World');
      expect(standardFilters['slug']!(null, []), '');
    });

    test('collection filters length, first, last, join, sort, reverse, slice', () {
      final length = standardFilters['length']!;
      expect(length(null, []), 0);
      expect(length(12345, []), 0);
      expect(length('abc', []), 3);
      expect(length([1, 2], []), 2);
      expect(length({'a': 1, 'b': 2}, []), 2);

      final first = standardFilters['first']!;
      expect(first(null, []), isNull);
      expect(first([], []), isNull);
      expect(first('', []), isNull);
      expect(first([1, 2], []), 1);
      expect(first('hello', []), 'h');

      final last = standardFilters['last']!;
      expect(last(null, []), isNull);
      expect(last([], []), isNull);
      expect(last('', []), isNull);
      expect(last([1, 2], []), 2);
      expect(last('hello', []), 'o');

      final join = standardFilters['join']!;
      expect(join(null, []), '');
      expect(join(123, []), '123');
      expect(join(['a', 'b'], ['-']), 'a-b');

      final sort = standardFilters['sort']!;
      expect(sort(null, []), isNull);
      expect(sort({'b', 'a'}, []), ['a', 'b']);
      expect(sort(42, []), 42);

      final reverse = standardFilters['reverse']!;
      expect(reverse(null, []), isNull);
      expect(reverse([1, 2], []), [2, 1]);
      expect(reverse({'a', 'b'}, []), ['b', 'a']);
      expect(reverse('abc', []), 'cba');
      expect(reverse(42, []), 42);

      final slice = standardFilters['slice']!;
      expect(slice(['a', 'b', 'c', 'd'], [1, 3]), ['b', 'c']);
      expect(slice('abcdef', [2, 4]), 'cd');
      expect(slice(123, [0, 1]), 123);
    });

    test('default, replace, parse_json edge cases', () {
      final defaultFilter = standardFilters['default']!;
      expect(defaultFilter(null, ['fallback']), 'fallback');
      expect(defaultFilter('', ['fallback']), 'fallback');
      expect(defaultFilter(false, ['fallback']), false);
      expect(defaultFilter(0, ['fallback']), 0);
      expect(defaultFilter('val', ['fallback']), 'val');

      final parseJson = standardFilters['parse_json']!;
      expect(parseJson(null, []), isNull);
      expect(parseJson('{"valid": 1}', []), {'valid': 1});
      expect(parseJson('invalid-json', []), isNull);

      final encodeUri = standardFilters['encode_uri']!;
      expect(encodeUri(null, []), '');
      expect(encodeUri('hello world', []), 'hello%20world');

      final decodeUri = standardFilters['decode_uri']!;
      expect(decodeUri(null, []), '');
      expect(decodeUri('hello%20world', []), 'hello world');
    });

    test('calc and nth edge cases', () {
      final calc = standardFilters['calc']!;
      expect(calc(null, ['+ 1']), isNull);
      expect(calc(10, ['- 4']), 6);
      expect(calc(10, ['* 4']), 40);
      expect(calc(10, ['/ 2']), 5);
      expect(calc(10, ['/ 0']), 0);
      expect(calc(2, ['^ 3']), 8);
      expect(calc(2, ['** 3']), 8);
      expect(calc(10, ['unknown_op 5']), 10);
      expect(calc(10, []), 10);
      expect(calc(10, ['+ invalid']), 10);

      final nth = standardFilters['nth']!;
      expect(nth(null, [1]), isNull);
      expect(nth([10, 20, 30], [2]), [20]);
      expect(nth([10, 20, 30], [99]), isEmpty);
      expect(nth(42, [1]), 42);
    });

    test('object, template, uncamel, unescape', () {
      final objectFilter = standardFilters['object']!;
      expect(objectFilter(null, []), isNull);
      expect(objectFilter([1, 2], []), [1, 2]);
      expect(objectFilter({'a': 1}, ['keys']), ['a']);
      expect(objectFilter({'a': 1}, ['values']), [1]);
      expect(objectFilter({'a': 1}, ['array']), [
        ['a', 1]
      ]);
      expect(objectFilter('{"x": 10}', ['keys']), ['x']);
      expect(objectFilter('invalid_json', []), 'invalid_json');
      expect(objectFilter({'a': 1}, ['unknown_mode']), {'a': 1});

      final templateFilter = standardFilters['template']!;
      expect(templateFilter(null, ['tpl']), '');
      expect(templateFilter(null, []), '');
      expect(templateFilter('item', [r'prefix: ${str}']), 'prefix: item');

      final uncamel = standardFilters['uncamel']!;
      expect(uncamel(null, []), '');
      expect(uncamel('myVariableName', [' ']), 'my variable name');

      final unescape = standardFilters['unescape']!;
      expect(unescape(null, []), '');
      expect(unescape(r'\"hello\nworld\"', []), '"hello\nworld"');
    });

    test('html attribute filters: strip_attr, remove_attr, replace_tags', () {
      final stripAttr = standardFilters['strip_attr']!;
      expect(stripAttr(null, ['class']), '');
      expect(stripAttr('<div class="a" id="b"></div>', ['class']), '<div class="a"></div>');
      expect(stripAttr('<div class="a" id="b"></div>', []), '<div></div>');

      final removeAttr = standardFilters['remove_attr']!;
      expect(removeAttr('<div class="a"></div>', ['class']), '<div></div>');
      expect(removeAttr('<div class="a"></div>', []), '<div class="a"></div>');

      final replaceTags = standardFilters['replace_tags']!;
      expect(replaceTags(null, ['p', 'div']), '');
      expect(replaceTags('<p>text</p>', ['p', 'div']), '<div>text</div>');
    });
  });
}
