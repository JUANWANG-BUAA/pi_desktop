import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/src/ui/pi_tokens.dart';
import 'package:pi_desktop/src/ui/transcript_pane.dart';

void main() {
  testWidgets('renders Pi-owned user image payloads as attachment previews', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: <ThemeExtension<dynamic>>[
            PiTokens.dark(PiDensity.standard),
          ],
        ),
        home: Scaffold(
          body: MessageDocument.fromMessage(<String, dynamic>{
            'role': 'user',
            'content': <Map<String, dynamic>>[
              <String, dynamic>{'type': 'text', 'text': 'Please inspect this'},
              <String, dynamic>{
                'type': 'image',
                'data': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLtewAAAABJRU5ErkJggg==',
                'mimeType': 'image/png',
              },
            ],
          }),
        ),
      ),
    );

    expect(find.text('Please inspect this'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel('Attached image preview'), findsOneWidget);
  });
}
