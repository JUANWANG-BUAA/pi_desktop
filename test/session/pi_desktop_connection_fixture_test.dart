import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/pi_desktop.dart';

/// Exercises [PiDesktopConnection] against the scripted fixture Pi process.
///
/// The official-Pi smoke test covers happy paths against the real binary;
/// this file pins the desktop behavior for responses Pi uses to signal
/// rejections and extension vetoes, which the UI must surface instead of
/// swallowing.
void main() {
  late Directory fixtureDirectory;
  late String fixtureExecutable;

  setUpAll(() async {
    final fixturePath =
        '${Directory.current.path}/test/fixtures/rpc_protocol_fixture.dart';
    fixtureDirectory = await Directory.systemTemp.createTemp(
      'pi-desktop-connection-fixture-',
    );
    fixtureExecutable = '${fixtureDirectory.path}/rpc_protocol_fixture';

    final result = await Process.run('dart', <String>[
      'compile',
      'exe',
      fixturePath,
      '-o',
      fixtureExecutable,
    ]);
    expect(
      result.exitCode,
      0,
      reason: 'Could not compile connection fixture: ${result.stderr}',
    );
  });

  tearDownAll(() async {
    await fixtureDirectory.delete(recursive: true);
  });

  test(
    'surfaces Pi rejections and extension vetoes without rewriting them',
    () async {
      final connection = PiDesktopConnection(
        executable: fixtureExecutable,
        arguments: const <String>[],
      );
      addTearDown(connection.dispose);

      await connection.connect();
      expect(connection.status, PiConnectionStatus.connected);

      // success:false responses reach the caller unmodified.
      final rejected = await connection.prompt('hello');
      expect(rejected.success, isFalse);
      expect(rejected.error, 'fixture rejected prompt');

      // fork / switch_session can be vetoed by a Pi extension with
      // success:true + data.cancelled; the flag must be visible to callers.
      final fork = await connection.fork('entry-1');
      expect(fork.success, isTrue);
      expect(fork.cancelledByExtension, isTrue);

      final switched = await connection.switchSession('/tmp/other.jsonl');
      expect(switched.success, isTrue);
      expect(switched.cancelledByExtension, isTrue);

      await connection.disconnect();
      expect(connection.status, PiConnectionStatus.disconnected);
    },
  );
}
