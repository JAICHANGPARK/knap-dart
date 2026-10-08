import '../errors/exceptions.dart';

/// Parses comma-delimited CSV text into a list of row maps keyed by header column names.
///
/// Supports quoted fields, escaped quotes (`""`), and embedded newlines, matching upstream `obsidianmd/knap`.
List<Map<String, String>> parseCsv(String input, {String source = 'csv'}) {
  final text = input.startsWith('\uFEFF') ? input.substring(1) : input;
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  var closedQuote = false;
  var started = false;
  var line = 1;

  Never fail(String message) {
    throw KnapSyntaxException('$source:$line: Invalid CSV: $message');
  }

  void endField() {
    row.add(field.toString());
    field.clear();
    closedQuote = false;
  }

  void endRow() {
    if (started || row.isNotEmpty) {
      endField();
      rows.add(row);
    }
    row = <String>[];
    started = false;
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          closedQuote = true;
        }
      } else {
        field.write(char);
        if (char == '\n' ||
            (char == '\r' && (i + 1 >= text.length || text[i + 1] != '\n'))) {
          line++;
        }
      }
      continue;
    }

    if (char == ',') {
      endField();
      started = true;
    } else if (char == '\n' || char == '\r') {
      endRow();
      if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
        i++;
      }
      line++;
    } else if (closedQuote) {
      fail('Unexpected character after a closing quote.');
    } else if (char == '"') {
      if (field.isNotEmpty) {
        fail('Quote inside an unquoted field.');
      }
      quoted = true;
      started = true;
    } else {
      field.write(char);
      started = true;
    }
  }

  if (quoted) {
    fail('Unclosed quoted field.');
  }
  endRow();

  if (rows.isEmpty) {
    throw KnapSyntaxException('$source: CSV requires nonempty column headers.');
  }

  final headers = rows.removeAt(0);
  if (headers.isEmpty || headers.any((h) => h.trim().isEmpty)) {
    throw KnapSyntaxException('$source: CSV requires nonempty column headers.');
  }
  if (headers.toSet().length != headers.length) {
    throw KnapSyntaxException('$source: CSV column headers must be unique.');
  }

  final records = <Map<String, String>>[];
  for (var idx = 0; idx < rows.length; idx++) {
    final values = rows[idx];
    if (values.length != headers.length) {
      throw KnapSyntaxException(
        '$source: CSV record ${idx + 1} has ${values.length} fields; expected ${headers.length}.',
      );
    }
    final record = <String, String>{};
    for (var col = 0; col < headers.length; col++) {
      record[headers[col]] = values[col];
    }
    records.add(record);
  }
  return records;
}
