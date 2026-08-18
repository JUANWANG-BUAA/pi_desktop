import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/pi_desktop.dart';

void main() {
  final piAvailable = _isPiAvailable();

  test('restores the UI projection from Pi RPC state', () async {
    final connection = PiDesktopConnection(
      arguments: const <String>[
        '--mode',
        'rpc',
        '--no-session',
        '--no-approve',
      ],
      environment: <String, String>{
        ...Platform.environment,
        'PI_OFFLINE': '1',
        'PI_SKIP_VERSION_CHECK': '1',
        'PI_TELEMETRY': '0',
      },
    );
    addTearDown(connection.dispose);

    await connection.connect();

    expect(connection.status, PiConnectionStatus.connected);
    expect(connection.projection?.state, isNotNull);
    expect(connection.projection?.entries, isNotNull);
    expect(connection.projection?.tree, isNotNull);
    expect(connection.projection?.commands, isNotNull);

    await connection.disconnect();
    expect(connection.status, PiConnectionStatus.disconnected);
  }, skip: piAvailable ? false : 'pi is not installed on this host');
}

bool _isPiAvailable() {
  try {
    return Process.runSync('pi', <String>['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}
