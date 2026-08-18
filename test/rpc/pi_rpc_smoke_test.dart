import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/pi_desktop.dart';

import '../support/pi_test_host.dart';

void main() {
  final version = piVersion();

  test('connects to the official Pi RPC baseline', () async {
    // The compatibility baseline is pinned; a different pi on PATH must not
    // silently pass the protocol smoke (docs/pi-baseline.md).
    expect(
      version,
      piBaselineVersion,
      reason:
          'docs/pi-baseline.md pins Pi $piBaselineVersion as the RPC '
          'compatibility baseline. Update the baseline and re-run the '
          'compatibility checks before widening support.',
    );

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
  }, skip: version == null ? 'pi is not installed on this host' : false);
}
