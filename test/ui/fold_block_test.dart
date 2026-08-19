import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/src/ui/pi_tokens.dart';
import 'package:pi_desktop/src/ui/widgets.dart';

void main() {
  testWidgets('expanded FoldBlock keeps a bounded viewport for long traces', (
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
          body: Center(
            child: SizedBox(
              width: 480,
              child: FoldBlock(
                title: 'Pi activity · 12 steps',
                child: SizedBox(height: 2400, child: Text('long-trace-body')),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(FoldBlock)).height, lessThan(80));

    await tester.tap(find.text('Pi activity · 12 steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));

    expect(find.text('long-trace-body'), findsOneWidget);
    expect(
      tester.getSize(find.byType(FoldBlock)).height,
      lessThan(kFoldBlockMaxHeight + 80),
    );
    expect(tester.getSize(find.byType(FoldBlock)).height, greaterThan(120));
  });
}
