import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final decoded = jsonDecode(line);
    if (decoded is! Map) {
      continue;
    }
    final command = Map<String, dynamic>.from(decoded);
    final type = command['type'];
    final id = command['id'];

    switch (type) {
      case 'get_state':
        _writeResponse(
          id,
          type,
          data: <String, dynamic>{
            'model': <String, dynamic>{
              'provider': 'fixture',
              'id': 'fixture-model',
            },
            'thinkingLevel': 'low',
            'isStreaming': false,
            'sessionName': 'Fixture Session',
            'sessionId': 'fixture-session',
            'sessionFile': '/tmp/fixture-session.jsonl',
            'steeringMode': 'all',
            'followUpMode': 'one-at-a-time',
            'autoCompactionEnabled': true,
          },
        );
      case 'get_messages':
        _writeResponse(
          id,
          type,
          data: <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{'role': 'user', 'content': 'fixture prompt'},
            ],
          },
        );
      case 'get_entries':
        _writeResponse(
          id,
          type,
          data: <String, dynamic>{
            'entries': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'entry-1', 'type': 'message'},
            ],
          },
        );
      case 'get_tree':
        _writeResponse(
          id,
          type,
          data: <String, dynamic>{
            'tree': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'entry-1'},
            ],
          },
        );
      case 'get_commands':
        _writeResponse(
          id,
          type,
          data: <String, dynamic>{
            'commands': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'fixture-command',
                'source': 'extension',
                'path': '/fixture/command.ts',
              },
            ],
          },
        );
      case 'get_available_models':
        _writeResponse(
          id,
          type,
          data: <String, dynamic>{
            'models': <Map<String, dynamic>>[
              <String, dynamic>{'provider': 'fixture', 'id': 'fixture-model'},
            ],
          },
        );
      case 'get_available_thinking_levels':
        _writeResponse(
          id,
          type,
          data: <String, dynamic>{
            'levels': <String>['low', 'high'],
          },
        );
      case 'get_fork_messages':
        _writeResponse(
          id,
          type,
          data: <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{'entryId': 'entry-1', 'text': 'fixture prompt'},
            ],
          },
        );
      case 'get_session_stats':
        _writeResponse(
          id,
          type,
          data: <String, dynamic>{
            'tokens': <String, dynamic>{'total': 42},
          },
        );
      case 'emit_event':
        final event = command['event'];
        if (event is Map) {
          _write(Map<String, dynamic>.from(event));
        }
        _writeResponse(id, type, data: <String, dynamic>{'ok': true});
      case 'event_then_response':
        _write({'type': 'test_event', 'text': 'before\u2028response'});
        _writeResponse(
          id,
          type,
          data: <String, dynamic>{'ok': true},
          crlf: true,
        );
      case 'delayed':
        final delayMs = command['delayMs'] as int? ?? 0;
        await Future<void>.delayed(Duration(milliseconds: delayMs));
        _writeResponse(
          id,
          type,
          data: <String, dynamic>{'value': command['value']},
        );
      case 'stderr':
        stderr.writeln('stderr stays separate');
        _writeResponse(id, type, data: <String, dynamic>{'ok': true});
      case 'request_ui':
        _write(<String, dynamic>{
          'type': 'extension_ui_request',
          'id': 'ui-1',
          'method': 'confirm',
          'title': 'Allow?',
          'message': 'Continue?',
        });
        _writeResponse(id, type, data: <String, dynamic>{'accepted': true});
      case 'extension_ui_response':
        _write(<String, dynamic>{
          'type': 'ui_response_received',
          'value': command['value'],
          'confirmed': command['confirmed'],
          'cancelled': command['cancelled'],
        });
      case 'failure':
        _writeResponse(id, type, success: false, error: 'fixture failure');
      case 'exit':
        exit(7);
      default:
        _writeResponse(id, type, data: <String, dynamic>{'echo': type});
    }
  }
}

void _writeResponse(
  Object? id,
  Object? command, {
  bool success = true,
  Object? data,
  String? error,
  bool crlf = false,
}) {
  _write(<String, dynamic>{
    'type': 'response',
    'id': id,
    'command': command,
    'success': success,
    'data': data,
    'error': error,
  }, crlf: crlf);
}

void _write(Map<String, dynamic> value, {bool crlf = false}) {
  stdout.write('${jsonEncode(value)}${crlf ? '\r\n' : '\n'}');
}
