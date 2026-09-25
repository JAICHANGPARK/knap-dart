import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:knap/knap.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addCommand('render')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Print this usage information.')
    ..addFlag('version', abbr: 'v', negatable: false, help: 'Print Knap version.');

  parser.commands['render']!
    ..addOption('data', abbr: 'd', help: 'Path to JSON file containing data variables.')
    ..addOption('output', abbr: 'o', help: 'Output markdown file path (defaults to stdout).')
    ..addOption('template', abbr: 't', help: 'Inline template string to render.');

  try {
    final results = parser.parse(arguments);

    if (results['help'] == true || arguments.isEmpty) {
      _printUsage(parser);
      exit(0);
    }

    if (results['version'] == true) {
      stdout.writeln('Knap Dart 0.1.0');
      exit(0);
    }

    final command = results.command;
    if (command == null || command.name != 'render') {
      _printUsage(parser);
      exit(1);
    }

    _handleRender(command);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

void _handleRender(ArgResults command) {
  String templateContent = '';

  if (command['template'] != null) {
    templateContent = command['template'] as String;
  } else if (command.rest.isNotEmpty) {
    final templateFile = File(command.rest.first);
    if (!templateFile.existsSync()) {
      stderr.writeln('Error: Template file "${templateFile.path}" not found.');
      exit(1);
    }
    templateContent = templateFile.readAsStringSync();
  } else {
    stderr.writeln('Error: Please provide a template file or --template option.');
    exit(1);
  }

  Map<String, Object?> data = {};
  if (command['data'] != null) {
    final rawDataArg = (command['data'] as String).trim();
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

  final engine = KnapEngine.standard();
  final rendered = engine.render(templateContent, data: data);

  if (command['output'] != null) {
    final outFile = File(command['output'] as String);
    outFile.writeAsStringSync(rendered);
    stdout.writeln('Successfully rendered to ${outFile.path}');
  } else {
    stdout.write(rendered);
  }
}

void _printUsage(ArgParser parser) {
  stdout.writeln('Knap: Safe template engine for Markdown in Dart\n');
  stdout.writeln('Usage:');
  stdout.writeln('  dart run knap render <template.md> --data <data.json> [--output <note.md>]');
  stdout.writeln('  dart run knap render --template "Hello {{ name }}" --data <data.json>\n');
  stdout.writeln(parser.usage);
}
