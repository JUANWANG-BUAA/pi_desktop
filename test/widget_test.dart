import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_desktop/main.dart';
import 'package:pi_desktop/src/ui/pi_tokens.dart';
import 'package:pi_desktop/src/ui/ui_preferences.dart';

void main() {
  testWidgets('renders the Pi Desktop workspace', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final preferences = UiPreferences()..inspectorVisible = false;
    addTearDown(preferences.dispose);

    await tester.pumpWidget(
      PiDesktopApp(
        autoConnect: false,
        enableRuntimeInspection: false,
        preferences: preferences,
      ),
    );

    expect(find.text('Pi Desktop'), findsOneWidget);
    expect(find.text('New task'), findsOneWidget);
    expect(find.text('Recents'), findsOneWidget);
    expect(find.text('Connect Pi to begin'), findsOneWidget);
    expect(find.text('Prompt will be sent through Pi RPC'), findsOneWidget);
    expect(find.text('Inspector'), findsNothing);
    expect(find.textContaining('Work in'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
  });

  testWidgets('toggles the light display without changing chrome labels', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final preferences = UiPreferences()..inspectorVisible = false;
    addTearDown(preferences.dispose);

    await tester.pumpWidget(
      PiDesktopApp(
        autoConnect: false,
        enableRuntimeInspection: false,
        preferences: preferences,
      ),
    );

    await tester.tap(find.byTooltip('Switch to light display'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(preferences.themeMode, ThemeMode.light);
    expect(find.text('New task'), findsOneWidget);
    expect(find.text('Pi Desktop'), findsOneWidget);
  });

  testWidgets('updates reading preferences from settings', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final preferences = UiPreferences()..inspectorVisible = false;
    addTearDown(preferences.dispose);
    await tester.pumpWidget(
      PiDesktopApp(
        autoConnect: false,
        enableRuntimeInspection: false,
        preferences: preferences,
      ),
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Reading font'), findsOneWidget);
    expect(find.text('Pi apps & extensions'), findsOneWidget);

    await tester.tap(find.text('Serif'));
    await tester.pump();
    expect(preferences.readingFont, PiReadingFont.serif);

    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pump();
    expect(preferences.textScale, greaterThan(1));
  });

  testWidgets('opens a workspace switcher from the sidebar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final preferences = UiPreferences()..inspectorVisible = false;
    addTearDown(preferences.dispose);
    await tester.pumpWidget(
      PiDesktopApp(
        autoConnect: false,
        enableRuntimeInspection: false,
        preferences: preferences,
      ),
    );

    await tester.tap(find.byKey(const Key('workspace-switcher')));
    await tester.pump();

    expect(find.text('Switch workspace'), findsOneWidget);
    expect(find.text('Choose folder'), findsOneWidget);
  });

  testWidgets('opens the Pi activity and capability panel', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final preferences = UiPreferences()..inspectorVisible = false;
    addTearDown(preferences.dispose);
    await tester.pumpWidget(
      PiDesktopApp(
        autoConnect: false,
        enableRuntimeInspection: false,
        preferences: preferences,
      ),
    );

    await tester.tap(find.byTooltip('Show Pi details, tools and commands'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(preferences.inspectorVisible, isTrue);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Pi capabilities'), findsNothing);

    await tester.tap(find.byType(Tab).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Workspace files'), findsOneWidget);

    await tester.tap(find.byType(Tab).at(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Pi capabilities'), findsOneWidget);

    await tester.tap(find.byType(Tab).at(4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text(
        'The latest Pi assistant response will appear here as Markdown.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('temporarily collapses side panels in a narrow window', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final preferences = UiPreferences()..inspectorVisible = true;
    addTearDown(preferences.dispose);
    await tester.pumpWidget(
      PiDesktopApp(
        autoConnect: false,
        enableRuntimeInspection: false,
        preferences: preferences,
      ),
    );

    expect(find.text('New task'), findsNothing);
    expect(find.text('Inspector'), findsNothing);
    expect(find.byTooltip('Widen window to show sessions'), findsOneWidget);
    expect(
      find.byTooltip('Show Pi details, tools and commands'),
      findsOneWidget,
    );
  });
}
