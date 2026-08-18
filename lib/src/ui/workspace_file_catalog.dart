import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A small, read-only view of the selected workspace.
///
/// This deliberately stays shallow and bounded: it is a navigation aid for
/// the desktop chrome, not an indexer, watcher, or second workspace model.
class WorkspaceFileCatalog {
  const WorkspaceFileCatalog(this.workspacePath);

  final String workspacePath;

  Future<List<WorkspaceFileEntry>> load() async {
    final root = Directory(workspacePath);
    if (!await root.exists()) return const <WorkspaceFileEntry>[];
    final entries = <WorkspaceFileEntry>[];
    try {
      await for (final entity in root.list(followLinks: false)) {
        final name = _basename(entity.path);
        final FileSystemEntityType type;
        try {
          type = await FileSystemEntity.type(entity.path, followLinks: false);
        } on FileSystemException {
          // A single protected or disappearing entry should not hide the rest
          // of the selected workspace.
          continue;
        }
        if (type == FileSystemEntityType.directory &&
            _hiddenDirectories.contains(name)) {
          continue;
        }
        entries.add(
          WorkspaceFileEntry(
            path: entity.path,
            name: name,
            directory: type == FileSystemEntityType.directory,
          ),
        );
      }
    } on FileSystemException {
      // Preserve entries discovered before a directory-level permission error.
    }
    entries.sort((a, b) {
      if (a.directory != b.directory) return a.directory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries.take(36).toList(growable: false);
  }
}

class WorkspaceFileEntry {
  const WorkspaceFileEntry({
    required this.path,
    required this.name,
    required this.directory,
  });

  final String path;
  final String name;
  final bool directory;
}

class WorkspaceFilePreview {
  const WorkspaceFilePreview({
    required this.text,
    required this.truncated,
    required this.binary,
  });

  final String text;
  final bool truncated;
  final bool binary;

  static Future<WorkspaceFilePreview> read(String path) async {
    const limit = 96 * 1024;
    final file = File(path);
    try {
      final length = await file.length();
      final handle = await file.open();
      final Uint8List bytes;
      try {
        bytes = await handle.read(limit);
      } finally {
        await handle.close();
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      final controls = text.runes
          .where((rune) => rune < 9 || (rune > 13 && rune < 32))
          .length;
      if (bytes.isNotEmpty && controls * 16 > text.runes.length) {
        return const WorkspaceFilePreview(
          text: 'Binary files are not previewed.',
          truncated: false,
          binary: true,
        );
      }
      return WorkspaceFilePreview(
        text: text,
        truncated: length > bytes.length,
        binary: false,
      );
    } on FileSystemException {
      return const WorkspaceFilePreview(
        text: 'This file is no longer available.',
        truncated: false,
        binary: false,
      );
    }
  }
}

const _hiddenDirectories = <String>{
  '.git',
  '.dart_tool',
  'build',
  'node_modules',
};

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}
