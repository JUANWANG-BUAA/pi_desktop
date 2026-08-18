import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/pi_desktop.dart';

void main() {
  final piAvailable = _isPiAvailable();

  test('connects to the official Pi RPC baseline', () async {
    final environment = <String, String>{
      ...Platform.environment,
      'PI_OFFLINE': '1',
      'PI_SKIP_VERSION_CHECK': '1',
      'PI_TELEMETRY': '0',
    };
    final client = await PiRpcClient.start(
      arguments: <String>['--mode', 'rpc', '--no-session', '--no-approve'],
      environment: environment,
    );
    addTearDown(client.close);

    final responses = await Future.wait(<Future<PiRpcResponse>>[
      client.sendCommand('get_state'),
      client.sendCommand('get_messages'),
      client.sendCommand('get_entries'),
      client.sendCommand('get_tree'),
      client.sendCommand('get_commands'),
      client.sendCommand('abort'),
    ]);

    expect(responses, hasLength(6));
    for (final response in responses) {
      expect(response.success, isTrue, reason: response.error);
    }
  }, skip: piAvailable ? false : 'pi is not installed on this host');
}

bool _isPiAvailable() {
  try {
    return Process.runSync('pi', <String>['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}
