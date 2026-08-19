import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/src/ui/pi_tokens.dart';
import 'package:pi_desktop/src/ui/transcript_pane.dart';

void main() {
  testWidgets('user turns expose copy and revert actions', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    var reverted = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: <ThemeExtension<dynamic>>[
            PiTokens.dark(PiDensity.standard),
          ],
        ),
        home: Scaffold(
          body: MessageDocument.fromMessage(
            <String, dynamic>{
              'role': 'user',
              'content': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'text',
                  'text': 'Please inspect this',
                },
              ],
            },
            forkEntryId: 'entry-1',
            onRevert: (id) async {
              expect(id, 'entry-1');
              reverted = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Please inspect this'), findsOneWidget);
    expect(find.byTooltip('Copy message'), findsOneWidget);
    expect(find.byTooltip('Revert'), findsOneWidget);

    await tester.tap(find.byTooltip('Copy message'));
    await tester.pump();
    await tester.tap(find.byTooltip('Revert'));
    await tester.pump();
    expect(reverted, isTrue);
  });

  testWidgets('assistant turns expose copy without revert', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: <ThemeExtension<dynamic>>[
            PiTokens.dark(PiDensity.standard),
          ],
        ),
        home: const Scaffold(
          body: MessageDocument(roleLabel: 'assistant', text: 'Done.'),
        ),
      ),
    );

    expect(find.byTooltip('Copy message'), findsOneWidget);
    expect(find.byTooltip('Revert'), findsNothing);
  });
}
