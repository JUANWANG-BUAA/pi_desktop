import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/src/session/pi_baseline.dart';
import 'package:pi_desktop/src/session/pi_desktop_connection.dart';

void main() {
  test('parses pi --version output', () {
    expect(PiRuntime.parseVersion('0.84.2\n'), '0.84.2');
    expect(PiRuntime.parseVersion('pi 0.84.2'), '0.84.2');
    expect(PiRuntime.parseVersion('v0.84.2'), '0.84.2');
  });

  test('gates a real pi basename and ignores RPC fixtures', () {
    expect(PiRuntime.shouldEnforceBaseline('pi'), isTrue);
    expect(PiRuntime.shouldEnforceBaseline('/opt/homebrew/bin/pi'), isTrue);
    expect(PiRuntime.shouldEnforceBaseline(r'C:\npm\pi.exe'), isTrue);
    expect(
      PiRuntime.shouldEnforceBaseline('/tmp/rpc_protocol_fixture'),
      isFalse,
    );
  });

  test('refuses to connect a pi binary that is not the baseline', () async {
    final directory = await Directory.systemTemp.createTemp('pi-version-gate-');
    addTearDown(() => directory.delete(recursive: true));
    final fake = File('${directory.path}/pi');
    await fake.writeAsString('#!/bin/sh\necho 0.84.1\nexit 0\n');
    await Process.run('chmod', <String>['+x', fake.path]);

    final connection = PiDesktopConnection(executable: fake.path);
    addTearDown(connection.dispose);
    await connection.connect();

    expect(connection.status, PiConnectionStatus.disconnected);
    expect(connection.errorMessage, contains('0.84.1'));
    expect(connection.errorMessage, contains(piBaselineVersion));
  });
}
