import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/pi_desktop.dart';

void main() {
  test('frames only on LF and accepts CRLF', () {
    final lines = <String>[];
    final framer = JsonlFramer(onLine: lines.add);

    final bytes = utf8.encode('{"text":"第一行"}\r\n{"text":"第二行"}\n');
    framer.add(bytes.sublist(0, 5));
    framer.add(bytes.sublist(5, 13));
    framer.add(bytes.sublist(13));
    framer.close();

    expect(lines, <String>['{"text":"第一行"}', '{"text":"第二行"}']);
  });

  test('does not treat Unicode line separators as record boundaries', () {
    final lines = <String>[];
    final framer = JsonlFramer(onLine: lines.add);

    framer.add(utf8.encode('{"text":"before\u2028after"}\n'));
    framer.close();

    expect(lines, <String>['{"text":"before\u2028after"}']);
  });

  test('preserves UTF-8 sequences split across byte chunks', () {
    final lines = <String>[];
    final framer = JsonlFramer(onLine: lines.add);
    final bytes = utf8.encode('{"text":"中文🙂"}\n');

    for (final byte in bytes) {
      framer.add(<int>[byte]);
    }
    framer.close();

    expect(lines, <String>['{"text":"中文🙂"}']);
  });

  test('emits a final unterminated record', () {
    final lines = <String>[];
    final framer = JsonlFramer(onLine: lines.add);

    framer.add(utf8.encode('{"final":true}'));
    framer.close();

    expect(lines, <String>['{"final":true}']);
  });

  test('rejects malformed UTF-8', () {
    final framer = JsonlFramer(onLine: (_) {});

    expect(() => framer.add(<int>[0xC3, 0x28]), throwsFormatException);
  });
}
