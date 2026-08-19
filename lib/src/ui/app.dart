import 'dart:async';

import 'package:flutter/material.dart';

import '../session/pi_desktop_connection.dart';
import 'extension_host.dart';
import 'pi_tokens.dart';
import 'shell.dart';
import 'ui_preferences.dart';

class PiDesktopApp extends StatefulWidget {
  const PiDesktopApp({
    super.key,
    this.autoConnect = true,
    this.enableRuntimeInspection = true,
    this.connection,
    this.preferences,
  });

  final bool autoConnect;
  final bool enableRuntimeInspection;
  final PiDesktopConnection? connection;
  final UiPreferences? preferences;

  @override
  State<PiDesktopApp> createState() => _PiDesktopAppState();
}

class _PiDesktopAppState extends State<PiDesktopApp> {
  late final PiDesktopConnection _connection;
  late final UiPreferences _preferences;
  late final bool _ownsConnection;
  late final bool _ownsPreferences;

  @override
  void initState() {
    super.initState();
    _connection = widget.connection ?? PiDesktopConnection();
    _ownsConnection = widget.connection == null;
    _preferences = widget.preferences ?? UiPreferences();
    _ownsPreferences = widget.preferences == null;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    if (_ownsPreferences) {
      await _preferences.load();
    }
    final workspace = _preferences.workspacePath?.trim();
    if (workspace != null && workspace.isNotEmpty && _ownsConnection) {
      _connection.applyWorkingDirectory(workspace);
    }
    if (widget.autoConnect && _ownsConnection) {
      await _connection.connect();
    }
  }

  @override
  void dispose() {
    if (_ownsConnection) {
      _connection.dispose();
    }
    if (_ownsPreferences) {
      _preferences.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _preferences,
      builder: (context, child) {
        final density = _preferences.density;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Pi Desktop',
          themeMode: _preferences.themeMode,
          theme: buildPiTheme(
            brightness: Brightness.light,
            density: density,
            readingFont: _preferences.readingFont,
            textScale: _preferences.textScale,
          ),
          darkTheme: buildPiTheme(
            brightness: Brightness.dark,
            density: density,
            readingFont: _preferences.readingFont,
            textScale: _preferences.textScale,
          ),
          builder: (context, child) {
            final tokens = PiTokens.of(context);
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                // This is a deliberate UI-only reading preference. System
                // accessibility scale still takes precedence when it is larger.
                textScaler: TextScaler.linear(_preferences.textScale)
                    .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.4),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontFamily: tokens.uiFontFamily,
                  fontFamilyFallback: tokens.uiFallbacks,
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: ExtensionHost(
            connection: _connection,
            child: DesktopShell(
              connection: _connection,
              preferences: _preferences,
              enableRuntimeInspection: widget.enableRuntimeInspection,
            ),
          ),
        );
      },
    );
  }
}
