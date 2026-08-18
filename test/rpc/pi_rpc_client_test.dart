import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/pi_desktop.dart';

void main() {
  late Directory fixtureDirectory;
  late String fixtureExecutable;

  setUpAll(() async {
    final fixturePath =
        '${Directory.current.path}/test/fixtures/rpc_protocol_fixture.dart';
    fixtureDirectory = await Directory.systemTemp.createTemp(
      'pi-desktop-rpc-fixture-',
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
      reason: 'Could not compile RPC fixture: ${result.stderr}',
    );
  });

  tearDownAll(() async {
    await fixtureDirectory.delete(recursive: true);
  });

  test('correlates responses while forwarding interleaved events', () async {
    final client = await _startFixture(fixtureExecutable);
    addTearDown(client.close);
    final events = <Map<String, dynamic>>[];
    final subscription = client.events.listen(events.add);
    addTearDown(subscription.cancel);

    final response = await client.sendCommand('event_then_response');

    expect(response.success, isTrue);
    expect(response.command, 'event_then_response');
    expect(response.data, <String, dynamic>{'ok': true});
    expect(events, hasLength(1));
    expect(events.single['type'], 'test_event');
    expect(events.single['text'], 'before\u2028response');
  });

  test('keeps concurrent responses associated with their request', () async {
    final client = await _startFixture(fixtureExecutable);
    addTearDown(client.close);

    final slow = client.sendCommand('delayed', <String, dynamic>{
      'delayMs': 40,
      'value': 'slow',
    });
    final fast = client.sendCommand('delayed', <String, dynamic>{
      'delayMs': 0,
      'value': 'fast',
    });
    final responses = await Future.wait(<Future<PiRpcResponse>>[slow, fast]);

    expect(responses[0].data, <String, dynamic>{'value': 'slow'});
    expect(responses[1].data, <String, dynamic>{'value': 'fast'});
  });

  test('keeps stderr out of the event stream', () async {
    final client = await _startFixture(fixtureExecutable);
    addTearDown(client.close);
    final stderrFuture = client.stderr.firstWhere(
      (chunk) => chunk.contains('stderr stays separate'),
    );

    final response = await client.sendCommand('stderr');

    expect(response.success, isTrue);
    expect(await stderrFuture, contains('stderr stays separate'));
  });

  test('returns unsuccessful Pi responses without rewriting them', () async {
    final client = await _startFixture(fixtureExecutable);
    addTearDown(client.close);

    final response = await client.sendCommand('failure');

    expect(response.success, isFalse);
    expect(response.error, 'fixture failure');
  });

  test('rejects pending requests when the process exits', () async {
    final client = await _startFixture(fixtureExecutable);

    final pending = client.sendCommand('exit');
    final pendingError = expectLater(pending, throwsA(isA<StateError>()));
    final exit = await client.done;

    expect(exit.exitCode, 7);
    await pendingError;
  });
}

Future<PiRpcClient> _startFixture(String fixtureExecutable) {
  return PiRpcClient.start(executable: fixtureExecutable);
}
