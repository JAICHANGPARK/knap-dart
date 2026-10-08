import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:knap/knap.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addCommand('render')
    ..addCommand('validate')
    ..addCommand('batch')
    ..addCommand('help')
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag('version', abbr: 'v', negatable: false, help: 'Print Knap version.');

  parser.commands['render']!
    ..addOption(
      'data',
      abbr: 'd',
      help: 'Path to JSON file containing data variables.',
    )
    ..addOption('data-json', help: 'Inline JSON object string.')
    ..addMultiOption('set', help: 'Override variable via key=value.')
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output markdown file path (defaults to stdout).',
    )
    ..addOption('template', abbr: 't', help: 'Inline template string to render.');

  parser.commands['validate']!
    ..addOption(
      'template',
      abbr: 't',
      help: 'Inline template string to validate.',
    );

  parser.commands['batch']!
    ..addOption(
      'data',
      abbr: 'd',
      help: 'Path to CSV or JSON array file containing batch records.',
    )
    ..addOption('data-json', help: 'Inline JSON array of objects.')
    ..addMultiOption('set', help: 'Override variable via key=value.')
    ..addOption('output-dir', help: 'Directory where rendered files are written.')
    ..addOption(
      'filename',
      help: 'Template for output filenames (e.g. "{{ title | safe_name }}.md").',
    )
    ..addFlag('overwrite', negatable: false, help: 'Overwrite existing files.')
    ..addOption('format', help: 'Input data format: csv or json.')
    ..addFlag(
      'dry-run',
      negatable: false,
      help: 'Print output paths without writing files.',
    )
    ..addOption('template', abbr: 't', help: 'Inline template string to render.');

  try {
    final results = parser.parse(arguments);

    if (results['help'] == true || arguments.isEmpty) {
      _printUsage(parser);
      exit(0);
    }

    if (results['version'] == true) {
      stdout.writeln('Knap Dart 2026.9.25');
      exit(0);
    }

    final command = results.command;
    if (command == null) {
      _printUsage(parser);
      exit(1);
    }

    switch (command.name) {
      case 'render':
        _handleRender(command);
        break;
      case 'validate':
        _handleValidate(command);
        break;
      case 'batch':
        _handleBatch(command);
        break;
      case 'help':
        _handleHelp(command);
        break;
      default:
        _printUsage(parser);
        exit(1);
    }
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

String _readTemplate(ArgResults command) {
  if (command['template'] != null) {
    return command['template'] as String;
  }
  if (command.rest.isNotEmpty) {
    final templateFile = File(command.rest.first);
    if (!templateFile.existsSync()) {
      stderr.writeln('Error: Template file "${templateFile.path}" not found.');
      exit(1);
    }
    return templateFile.readAsStringSync();
  }
  stderr.writeln('Error: Please provide a template file or --template option.');
  exit(1);
}

Map<String, String> _parseSetOverrides(List<String> setArgs) {
  final overrides = <String, String>{};
  for (final item in setArgs) {
    final sep = item.indexOf('=');
    if (sep < 1) {
      stderr.writeln('Error: --set requires key=value with a nonempty key.');
      exit(1);
    }
    overrides[item.substring(0, sep)] = item.substring(sep + 1);
  }
  return overrides;
}

void _handleRender(ArgResults command) {
  final templateContent = _readTemplate(command);
  final overrides = _parseSetOverrides(
    (command['set'] as List<String>?) ?? const [],
  );

  Map<String, Object?> data = {};
  final rawDataOpt = command['data'] ?? command['data-json'];
  if (rawDataOpt != null) {
    final rawDataArg = (rawDataOpt as String).trim();
    String rawJson;
    if (rawDataArg.startsWith('{')) {
      rawJson = rawDataArg;
    } else {
      final dataFile = File(rawDataArg);
      if (!dataFile.existsSync()) {
        stderr.writeln('Error: Data file "${dataFile.path}" not found.');
        exit(1);
      }
      rawJson = dataFile.readAsStringSync();
    }

    final decoded = jsonDecode(rawJson);
    if (decoded is Map<String, dynamic>) {
      data = decoded;
    } else {
      stderr.writeln('Error: Data must be a JSON object.');
      exit(1);
    }
  }
  data = {...data, ...overrides};

  final engine = KnapEngine.standard();
  final rendered = engine.render(templateContent, data: data);

  if (command['output'] != null) {
    final outFile = File(command['output'] as String);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsStringSync(rendered);
    stdout.writeln('Successfully rendered to ${outFile.path}');
  } else {
    stdout.write(rendered);
  }
}

void _handleValidate(ArgResults command) {
  final templateContent = _readTemplate(command);
  final engine = KnapEngine.standard();
  final errors = engine.validate(templateContent);
  if (errors.isEmpty) {
    stderr.writeln('Template is valid.');
    exit(0);
  }
  for (final err in errors) {
    stderr.writeln(err);
  }
  exit(1);
}

void _handleBatch(ArgResults command) {
  final outputDir = command['output-dir'] as String?;
  if (outputDir == null || outputDir.isEmpty) {
    stderr.writeln('Error: Batch requires --output-dir.');
    exit(1);
  }
  final templateContent = _readTemplate(command);
  final overrides = _parseSetOverrides(
    (command['set'] as List<String>?) ?? const [],
  );
  final dataOpt = command['data'] as String?;
  final dataJsonOpt = command['data-json'] as String?;
  if (dataOpt == null && dataJsonOpt == null) {
    stderr.writeln('Error: Batch requires --data or --data-json.');
    exit(1);
  }

  String rawText;
  var isCsv = command['format'] == 'csv';
  if (dataJsonOpt != null) {
    rawText = dataJsonOpt;
  } else {
    final file = File(dataOpt!);
    if (!file.existsSync()) {
      stderr.writeln('Error: Data file "${file.path}" not found.');
      exit(1);
    }
    rawText = file.readAsStringSync();
    if (command['format'] == null && dataOpt.toLowerCase().endsWith('.csv')) {
      isCsv = true;
    }
  }

  final List<Map<String, Object?>> records;
  if (isCsv) {
    records = parseCsv(rawText, source: dataOpt ?? 'stdin');
  } else {
    final decoded = jsonDecode(rawText);
    if (decoded is! List) {
      stderr.writeln('Error: Batch JSON data must be an array of objects.');
      exit(1);
    }
    records = decoded.whereType<Map>().map((m) => Map<String, Object?>.from(m)).toList();
  }

  final engine = KnapEngine.standard();
  final filenameTpl = command['filename'] as String?;
  final dryRun = command['dry-run'] == true;
  final overwrite = command['overwrite'] == true;
  final dir = Directory(outputDir);
  if (!dryRun) {
    dir.createSync(recursive: true);
  }

  for (var i = 0; i < records.length; i++) {
    final vars = <String, Object?>{...records[i], ...overrides};
    final fileName = filenameTpl != null
        ? engine.render(filenameTpl, data: vars).trim()
        : '${i + 1}.md';
    final outPath = '${dir.path}/$fileName';
    if (dryRun) {
      stdout.writeln(outPath);
      continue;
    }
    final outFile = File(outPath);
    if (outFile.existsSync() && !overwrite) {
      stderr.writeln(
        'Error: Output "$outPath" already exists. Use --overwrite to replace.',
      );
      exit(1);
    }
    final content = engine.render(templateContent, data: vars);
    outFile.writeAsStringSync(content);
  }
}

void _handleHelp(ArgResults command) {
  final engine = KnapEngine.standard();
  final filters = engine.filterRegistry.allSync.keys.toList()..sort();
  stdout.writeln('Knap Built-in Filters (${filters.length}):');
  stdout.writeln('  ${filters.join(', ')}');
}

void _printUsage(ArgParser parser) {
  stdout.writeln('Knap: Safe template engine for Markdown in Dart\n');
  stdout.writeln('Usage:');
  stdout.writeln(
    '  dart run knap render <template.md> --data <data.json> [--output <note.md>]',
  );
  stdout.writeln(
    '  dart run knap validate <template.md>',
  );
  stdout.writeln(
    '  dart run knap batch <template.md> --data <data.csv> --output-dir <out/>',
  );
  stdout.writeln('  dart run knap help\n');
  stdout.writeln(parser.usage);
}
