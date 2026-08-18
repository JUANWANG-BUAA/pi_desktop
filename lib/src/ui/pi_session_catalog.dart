import 'dart:convert';
import 'dart:io';

/// A read-only index over Pi's own session JSONL files. This is intentionally
/// not a session store: Pi remains responsible for restoring and switching.
class PiSessionCatalog {
  const PiSessionCatalog(this.workspacePath, {this.sessionsRoot});

  final String workspacePath;
  final String? sessionsRoot;

  Future<List<PiSessionSummary>> load() async {
    final home = Platform.environment['HOME'];
    if (home == null && sessionsRoot == null) return const [];
    final root = Directory(sessionsRoot ?? '$home/.pi/agent/sessions');
    if (!await root.exists()) return const [];
    final files = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.jsonl')) files.add(entity);
    }
    final dated = <({File file, DateTime modified})>[];
    for (final file in files) {
      final stat = await file.stat();
      dated.add((file: file, modified: stat.modified));
    }
    dated.sort((a, b) => b.modified.compareTo(a.modified));
    final results = <PiSessionSummary>[];
    for (final entry in dated.take(40)) {
      final summary = await _read(entry.file, entry.modified);
      if (summary != null && summary.workspacePath == workspacePath) {
        results.add(summary);
      }
      if (results.length == 12) break;
    }
    return results;
  }

  Future<PiSessionSummary?> _read(File file, DateTime modified) async {
    try {
      final handle = await file.open();
      final bytes = await handle.read(48 * 1024);
      await handle.close();
      final lines = utf8.decode(bytes, allowMalformed: true).split('\n');
      if (lines.isEmpty) return null;
      final header = jsonDecode(lines.first);
      if (header is! Map || header['type'] != 'session') return null;
      String? preview;
      for (final line in lines.skip(1)) {
        if (line.trim().isEmpty) continue;
        Object? entry;
        try {
          entry = jsonDecode(line);
        } on FormatException {
          // The bounded read may end in the middle of a JSONL record.
          continue;
        }
        if (entry is! Map || entry['type'] != 'message') continue;
        final message = entry['message'];
        if (message is! Map || message['role'] != 'user') continue;
        final content = message['content'];
        if (content is List) {
          for (final block in content) {
            if (block is Map && block['text'] is String) {
              preview = (block['text'] as String)
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim();
              break;
            }
          }
        }
        break;
      }
      return PiSessionSummary(
        path: file.path,
        workspacePath: header['cwd'] as String? ?? '',
        title: preview == null || preview.isEmpty
            ? 'Untitled session'
            : preview,
        modified: modified,
      );
    } on Object {
      return null;
    }
  }
}

class PiSessionSummary {
  const PiSessionSummary({
    required this.path,
    required this.workspacePath,
    required this.title,
    required this.modified,
  });

  final String path;
  final String workspacePath;
  final String title;
  final DateTime modified;
}
