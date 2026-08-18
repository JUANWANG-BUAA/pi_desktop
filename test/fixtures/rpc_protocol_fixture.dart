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
