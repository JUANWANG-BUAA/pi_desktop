import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('keeps ordered list numbering', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: <ThemeExtension<dynamic>>[
            PiTokens.dark(PiDensity.standard),
          ],
        ),
        home: const Scaffold(
          body: MarkdownDocument(text: '1. First step\n2. Second step'),
        ),
      ),
    );

    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('First step'), findsOneWidget);
    expect(find.text('Second step'), findsOneWidget);
  });

  testWidgets('renders links and copies the URL on tap', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: <ThemeExtension<dynamic>>[
            PiTokens.dark(PiDensity.standard),
          ],
        ),
        home: const Scaffold(
          body: MarkdownDocument(
            text: 'See [Pi docs](https://example.com/rpc) for details.',
          ),
        ),
      ),
    );

    expect(find.text('Pi docs'), findsOneWidget);
    await tester.tap(find.text('Pi docs'));
    await tester.pump();
    expect(find.text('Copied https://example.com/rpc'), findsOneWidget);
  });

  testWidgets('renders horizontal rules as a single divider', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: <ThemeExtension<dynamic>>[
            PiTokens.dark(PiDensity.standard),
          ],
        ),
        home: const Scaffold(
          body: MarkdownDocument(text: 'before\n\n---\n\nafter'),
        ),
      ),
    );

    expect(find.text('before'), findsOneWidget);
    expect(find.text('after'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 1,
      ),
      findsOneWidget,
    );
  });
}
