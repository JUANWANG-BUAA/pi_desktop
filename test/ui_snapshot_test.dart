import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/main.dart';
import 'package:pi_desktop/src/ui/ui_preferences.dart';

void main() {
  testWidgets('dark shell golden', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final preferences = UiPreferences();
    addTearDown(preferences.dispose);

    await tester.pumpWidget(
      PiDesktopApp(
        autoConnect: false,
        enableRuntimeInspection: false,
        preferences: preferences,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/shell_dark.png'),
    );
  }, tags: ['golden']);

  testWidgets('light shell golden', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final preferences = UiPreferences()..themeMode = ThemeMode.light;
    addTearDown(preferences.dispose);

    await tester.pumpWidget(
      PiDesktopApp(
        autoConnect: false,
        enableRuntimeInspection: false,
        preferences: preferences,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/shell_light.png'),
    );
  }, tags: ['golden']);
}
