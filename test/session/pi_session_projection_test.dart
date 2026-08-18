import 'dart:async';
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
      'pi-desktop-projection-fixture-',
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
      reason: 'Could not compile projection fixture: ${result.stderr}',
    );
  });

  tearDownAll(() async {
    await fixtureDirectory.delete(recursive: true);
  });

  test('loads authoritative state and projects Pi events', () async {
    final client = await PiRpcClient.start(executable: fixtureExecutable);
    final projection = PiSessionProjection(client);
    addTearDown(projection.dispose);
    addTearDown(client.close);

    await projection.load();

    expect(projection.state?['sessionName'], 'Fixture Session');
    expect(projection.messages, hasLength(1));
    expect(projection.entries?['entries'], isNotEmpty);
    expect(projection.tree?['tree'], isNotEmpty);
    expect(projection.commands.single['source'], 'extension');
    expect(projection.availableModels.single['id'], 'fixture-model');
    expect(projection.thinkingLevels, <String>['low', 'high']);
    expect(projection.sessionStats?['tokens']['total'], 42);

    await _emit(projection, client, <String, dynamic>{
      'type': 'message_start',
      'message': <String, dynamic>{'role': 'assistant'},
    });
    await _emit(projection, client, <String, dynamic>{
      'type': 'message_update',
      'assistantMessageEvent': <String, dynamic>{
        'type': 'text_delta',
        'delta': 'hello',
      },
    });
    expect(projection.streamingText, 'hello');

    await _emit(projection, client, <String, dynamic>{
      'type': 'tool_execution_start',
      'toolCallId': 'tool-1',
      'toolName': 'bash',
      'args': <String, dynamic>{'command': 'printf hello'},
    });
    await _emit(projection, client, <String, dynamic>{
      'type': 'tool_execution_end',
      'toolCallId': 'tool-1',
      'result': 'hello',
    });
    expect(projection.toolEvents, hasLength(1));
    expect(projection.toolEvents.single['result'], 'hello');
    expect(projection.documents.first.kind, PiTranscriptKind.message);
    expect(projection.documents.last.kind, PiTranscriptKind.liveTool);
    expect(projection.forkMessages.single['entryId'], 'entry-1');

    await _emit(projection, client, <String, dynamic>{
      'type': 'queue_update',
      'steering': <String>['interrupt'],
      'followUp': <String>['continue'],
    });
    expect(projection.steeringQueue, <String>['interrupt']);
    expect(projection.followUpQueue, <String>['continue']);

    await _emit(projection, client, <String, dynamic>{
      'type': 'compaction_start',
      'reason': 'fixture',
    });
    expect(projection.timelineEvents.single['type'], 'compaction_start');

    await _emit(projection, client, <String, dynamic>{
      'type': 'extension_error',
      'error': 'fixture extension failed',
    });
    expect(projection.lastError, 'fixture extension failed');

    // Streaming usage arrives on message_update and is projected verbatim.
    await _emit(projection, client, <String, dynamic>{
      'type': 'message_update',
      'usage': <String, dynamic>{
        'totalTokens': 101,
        'cost': <String, dynamic>{'total': 0.001},
      },
      'assistantMessageEvent': <String, dynamic>{
        'type': 'text_delta',
        'delta': ' world',
      },
    });
    expect(projection.streamingText, 'hello world');
    expect(projection.liveUsage?['totalTokens'], 101);

    // Once the run settles the projection refreshes Pi session stats so the
    // context meter stops drifting (fixture increments on every call).
    await _emit(projection, client, <String, dynamic>{'type': 'agent_settled'});
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (projection.sessionStats?['tokens']['total'] != 43) {
      if (DateTime.now().isAfter(deadline)) {
        fail('agent_settled did not refresh Pi session stats');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    await projection.load();
    expect(projection.toolEvents, isEmpty);
    expect(projection.timelineEvents, isEmpty);
    expect(projection.streamingText, isNull);
    expect(projection.liveUsage, isNull);
  });
}

Future<void> _emit(
  PiSessionProjection projection,
  PiRpcClient client,
  PiJsonObject event,
) async {
  final observed = Completer<void>();
  void listener() {
    if (projection.lastEventType == event['type'] && !observed.isCompleted) {
      observed.complete();
    }
  }

  projection.addListener(listener);
  try {
    final response = await client.sendCommand('emit_event', <String, dynamic>{
      'event': event,
    });
    expect(response.success, isTrue);
    await observed.future.timeout(const Duration(seconds: 2));
  } finally {
    projection.removeListener(listener);
  }
}
