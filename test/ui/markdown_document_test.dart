import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/src/ui/markdown_document.dart';
import 'package:pi_desktop/src/ui/pi_tokens.dart';

void main() {
  testWidgets('renders Pi markdown task lists as read-only checkboxes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: <ThemeExtension<dynamic>>[
            PiTokens.dark(PiDensity.standard),
          ],
        ),
        home: const Scaffold(
          body: MarkdownDocument(text: '- [ ] Pending\n- [x] Completed'),
        ),
      ),
    );

    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });
}
