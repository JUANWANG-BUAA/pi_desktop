import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/src/ui/workspace_file_catalog.dart';

void main() {
  test('lists only shallow, readable workspace entries', () async {
    final root = await Directory.systemTemp.createTemp('pi-workspace-catalog-');
    addTearDown(() => root.delete(recursive: true));
    await Directory('${root.path}/lib').create();
    await Directory('${root.path}/build').create();
    await File('${root.path}/README.md').writeAsString('# Preview');
    await File('${root.path}/lib/app.dart').writeAsString('void main() {}');

    final entries = await WorkspaceFileCatalog(root.path).load();

    expect(
      entries.map((entry) => entry.name),
      containsAll(<String>['lib', 'README.md']),
    );
    expect(entries.map((entry) => entry.name), isNot(contains('build')));
    expect(entries.map((entry) => entry.name), isNot(contains('app.dart')));
  });

  test('bounds text previews without persisting a copy', () async {
    final root = await Directory.systemTemp.createTemp('pi-workspace-preview-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/large.txt');
    await file.writeAsString('a' * (100 * 1024));

    final preview = await WorkspaceFilePreview.read(file.path);

    expect(preview.binary, isFalse);
    expect(preview.truncated, isTrue);
    expect(preview.text.length, lessThanOrEqualTo(96 * 1024));
  });
}
