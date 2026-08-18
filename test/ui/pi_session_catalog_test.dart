import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/src/ui/pi_session_catalog.dart';

void main() {
  test(
    'indexes a valid JSONL header when bounded read ends mid-record',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pi-sessions-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      const workspace = '/tmp/example-project';
      final file = File('${directory.path}/session.jsonl');
      await file.writeAsString(
        '{"type":"session","cwd":"$workspace"}\n'
        '{"type":"message","message":{"role":"user","content":[{"type":"text","text":"Inspect this project"}]}}\n'
        '${'x' * (60 * 1024)}',
      );

      final sessions = await PiSessionCatalog(
        workspace,
        sessionsRoot: directory.path,
      ).load();

      expect(sessions, hasLength(1));
      expect(sessions.single.title, 'Inspect this project');
    },
  );
}
