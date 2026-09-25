import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_knap/flutter_knap.dart';

void main() {
  runApp(const KnapPlaygroundApp());
}

class KnapPlaygroundApp extends StatelessWidget {
  const KnapPlaygroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Knap Flutter Playground',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED), // Obsidian purple
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const KnapPlaygroundScreen(),
    );
  }
}

class KnapPlaygroundScreen extends StatefulWidget {
  const KnapPlaygroundScreen({super.key});

  @override
  State<KnapPlaygroundScreen> createState() => _KnapPlaygroundScreenState();
}

class _KnapPlaygroundScreenState extends State<KnapPlaygroundScreen> {
  late final KnapTemplateController _controller;
  late final TextEditingController _templateTextController;
  late final TextEditingController _dataTextController;

  final Map<String, ({String template, String dataJson})> _presets = {
    'Web Clipper': (
      template: '''---
title: {{ title | yaml }}
clipped_at: "{{ "now" | date: "YYYY-MM-DD HH:mm" }}"
tags:
{{ tags | list }}
---

# {{ title }}

> [!NOTE] Summary
> {{ summary }}

## Key Highlights
{% for item in highlights -%}
- {{ item.text }} (Confidence: **{{ item.score }}%**)
{% endfor %}

## Related Notes
{% for link in links -%}
- {{ link | wikilink }}
{% endfor %}
''',
      dataJson: '''{
  "title": "Flutter & Knap Integration",
  "tags": ["flutter", "obsidian", "knap"],
  "summary": "Knap enables zero-eval, secure markdown templating.",
  "highlights": [
    {"text": "AST-based parsing is safe for user templates.", "score": 98},
    {"text": "Built-in whitespace control prevents broken markdown.", "score": 95}
  ],
  "links": ["Obsidian Web Clipper", "Dart Pub Workspaces"]
}''',
    ),
    'Daily Standup': (
      template: '''# Daily Standup - {{ "now" | date: "YYYY-MM-DD" }}

**Engineer**: {{ name }} ({{ role }})

## Completed Tasks
{{ completed | task_list }}

## In Progress
{{ in_progress | list }}

{% if blockers %}
> [!WARNING] Blockers
> {{ blockers }}
{% endif %}
''',
      dataJson: '''{
  "name": "Alex",
  "role": "Flutter Developer",
  "completed": [
    {"title": "Implement KnapLexer and AST", "done": true},
    {"title": "Add Markdown filters", "done": true}
  ],
  "in_progress": [
    "Build Flutter playground example",
    "Prepare documentation"
  ],
  "blockers": null
}''',
    ),
  };

  @override
  void initState() {
    super.initState();
    final defaultPreset = _presets['Web Clipper']!;
    _templateTextController = TextEditingController(text: defaultPreset.template);
    _dataTextController = TextEditingController(text: defaultPreset.dataJson);

    _controller = KnapTemplateController(
      initialTemplate: defaultPreset.template,
      initialData: jsonDecode(defaultPreset.dataJson) as Map<String, dynamic>,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _templateTextController.dispose();
    _dataTextController.dispose();
    super.dispose();
  }

  void _onTemplateChanged(String text) {
    _controller.template = text;
  }

  void _onDataChanged(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        _controller.data = decoded;
      }
    } catch (_) {}
  }

  void _applyPreset(String name) {
    final preset = _presets[name];
    if (preset == null) return;

    _templateTextController.text = preset.template;
    _dataTextController.text = preset.dataJson;

    _controller.update(
      template: preset.template,
      data: jsonDecode(preset.dataJson) as Map<String, dynamic>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knap Template Playground'),
        actions: [
          for (final presetName in _presets.keys)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                label: Text(presetName),
                onPressed: () => _applyPreset(presetName),
              ),
            ),
        ],
      ),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: _buildEditorSection(),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildPreviewSection(),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.edit_note), text: 'Editor'),
              Tab(icon: Icon(Icons.visibility), text: 'Preview'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: _buildEditorSection(),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildPreviewSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Template (.knap)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Expanded(
          flex: 3,
          child: TextField(
            controller: _templateTextController,
            onChanged: _onTemplateChanged,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(10),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('JSON Data Context', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Expanded(
          flex: 2,
          child: TextField(
            controller: _dataTextController,
            onChanged: _onDataChanged,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Live Rendered Markdown Output',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: KnapMarkdownView(
                  controller: _controller,
                  selectable: true,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
