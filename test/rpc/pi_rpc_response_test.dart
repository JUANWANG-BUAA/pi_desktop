import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/pi_desktop.dart';

void main() {
  group('PiRpcResponse', () {
    PiRpcResponse parse(Map<String, dynamic> json) {
      return PiRpcResponse.fromJson(json);
    }

    test('exposes extension cancellation from fork/switch data', () {
      final response = parse(<String, dynamic>{
        'type': 'response',
        'command': 'fork',
        'success': true,
        'id': 'r-1',
        'data': <String, dynamic>{'cancelled': true},
      });
      expect(response.success, isTrue);
      expect(response.cancelledByExtension, isTrue);
    });

    test('treats ordinary successful responses as not cancelled', () {
      final response = parse(<String, dynamic>{
        'type': 'response',
        'command': 'switch_session',
        'success': true,
        'id': 'r-2',
        'data': <String, dynamic>{'cancelled': false},
      });
      expect(response.cancelledByExtension, isFalse);

      final noData = parse(<String, dynamic>{
        'type': 'response',
        'command': 'abort',
        'success': true,
        'id': 'r-3',
      });
      expect(noData.cancelledByExtension, isFalse);
    });
  });
}
