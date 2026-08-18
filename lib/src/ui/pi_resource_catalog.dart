import 'dart:convert';
import 'dart:io';

/// Read-only local inventory of Pi resources. It intentionally mirrors only
/// files Pi itself discovers; it never loads or executes a resource.
class PiResourceCatalog {
  const PiResourceCatalog({required this.workspacePath});

  final String workspacePath;

  Future<PiResourceSnapshot> discover() async {
    final home = Platform.environment['HOME'];
    final agentDir = home == null ? null : Directory('$home/.pi/agent');
    final userSkills = agentDir == null
        ? null
        : Directory('${agentDir.path}/skills');
    final projectSkills = Directory('$workspacePath/.pi/skills');
    final extensions = <PiResourceEntry>[];
    final skills = <PiResourceEntry>[];
    final prompts = <PiResourceEntry>[];
    final themes = <PiResourceEntry>[];
    final mcps = <PiResourceEntry>[];

    await _readSkills(userSkills, 'User', skills);
    await _readSkills(projectSkills, 'Project', skills);
    if (agentDir != null) {
      await _readPackages(agentDir, extensions, skills, prompts, themes, mcps);
    }
    await _readPackages(
      Directory('$workspacePath/.pi'),
      extensions,
      skills,
      prompts,
      themes,
      mcps,
    );
    return PiResourceSnapshot(
      extensions: extensions,
      skills: skills,
      prompts: prompts,
      themes: themes,
      mcps: mcps,
    );
  }

  Future<void> _readSkills(
    Directory? root,
    String scope,
    List<PiResourceEntry> into,
  ) async {
    if (root == null || !await root.exists()) return;
    try {
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !entity.path.endsWith('.md')) continue;
        final content = await entity.readAsString();
        final name =
            _frontmatter(content, 'name') ?? _basename(entity.path, '.md');
        final description = _frontmatter(content, 'description') ?? 'Pi skill';
        into.add(
          PiResourceEntry(name: name, detail: description, scope: scope),
        );
      }
    } on FileSystemException {
      // Inventory is optional UI metadata; inaccessible paths are omitted.
    }
  }

  Future<void> _readPackages(
    Directory root,
    List<PiResourceEntry> extensions,
    List<PiResourceEntry> skills,
    List<PiResourceEntry> prompts,
    List<PiResourceEntry> themes,
    List<PiResourceEntry> mcps,
  ) async {
    final settings = File('${root.path}/settings.json');
    if (!await settings.exists()) return;
    try {
      final data = jsonDecode(await settings.readAsString());
      if (data is! Map) return;
      _readSettingList(data['extensions'], 'Extension', extensions);
      _readSettingList(data['skills'], 'Skill path', skills);
      _readSettingList(data['promptTemplates'], 'Prompt template', prompts);
      _readSettingList(data['themes'], 'Theme', themes);
      _readMcpSettings(data['mcpServers'] ?? data['mcp'], mcps);
    } on FormatException {
      // Do not let a user-edited config file prevent Pi Desktop from starting.
    }
  }

  void _readMcpSettings(Object? value, List<PiResourceEntry> into) {
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key is String) {
          into.add(
            PiResourceEntry(
              name: entry.key as String,
              detail: 'MCP server',
              scope: 'Config',
            ),
          );
        }
      }
    }
    if (value is List) {
      _readSettingList(value, 'MCP server', into);
    }
  }

  void _readSettingList(
    Object? value,
    String detail,
    List<PiResourceEntry> into,
  ) {
    if (value is! List) return;
    for (final item in value.whereType<String>()) {
      into.add(
        PiResourceEntry(
          name: _basename(item, ''),
          detail: detail,
          scope: 'Config',
        ),
      );
    }
  }

  String? _frontmatter(String content, String key) {
    final match = RegExp(
      '^$key\\s*:\\s*["\\\']?([^\\n"\\\']+)',
      multiLine: true,
    ).firstMatch(content);
    return match?.group(1)?.trim();
  }

  String _basename(String value, String suffix) {
    final segments = value.split(Platform.pathSeparator);
    final name = segments.isEmpty ? value : segments.last;
    return suffix.isNotEmpty && name.endsWith(suffix)
        ? name.substring(0, name.length - suffix.length)
        : name;
  }
}

class PiResourceSnapshot {
  const PiResourceSnapshot({
    required this.extensions,
    required this.skills,
    required this.prompts,
    required this.themes,
    required this.mcps,
  });

  final List<PiResourceEntry> extensions;
  final List<PiResourceEntry> skills;
  final List<PiResourceEntry> prompts;
  final List<PiResourceEntry> themes;
  final List<PiResourceEntry> mcps;
}

class PiResourceEntry {
  const PiResourceEntry({
    required this.name,
    required this.detail,
    required this.scope,
  });

  final String name;
  final String detail;
  final String scope;
}
