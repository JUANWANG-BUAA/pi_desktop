import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_desktop/main.dart';

void main() {
  testWidgets('renders the Pi Desktop shell', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PiDesktopApp(autoConnect: false));

    expect(find.text('Pi Desktop'), findsOneWidget);
    expect(find.text('Session Archive'), findsOneWidget);
    expect(find.text('Transcript'), findsOneWidget);
    expect(find.text('Inspector'), findsOneWidget);
    expect(find.text('No Pi Session loaded'), findsOneWidget);
    expect(find.text('Prompt will be sent through Pi RPC'), findsOneWidget);
  });
}
