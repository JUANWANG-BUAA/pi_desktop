import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'pi_tokens.dart';

/// Pure UI preferences. These never enter Pi Agent context.
class UiPreferences extends ChangeNotifier {
  UiPreferences();

  ThemeMode themeMode = ThemeMode.dark;
  PiDensity density = PiDensity.standard;
  PiReadingFont readingFont = PiReadingFont.sans;
  double textScale = 1;
  double archiveWidth = 244;
  double inspectorWidth = 336;
  bool archiveVisible = true;
  bool inspectorVisible = true;
  String? workspacePath;
  List<String> recentWorkspacePaths = const <String>[];
  List<String> pinnedSessionPaths = const <String>[];
  List<String> archivedSessionPaths = const <String>[];
  var _layoutVersion = 0;
  var _ready = false;
  Timer? _saveTimer;

  bool get isReady => _ready;

  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        if (json is Map<String, dynamic>) {
          themeMode = json['themeMode'] == 'light'
              ? ThemeMode.light
              : ThemeMode.dark;
          density = json['density'] == 'compact'
              ? PiDensity.compact
              : PiDensity.standard;
          readingFont = PiReadingFont.parse(json['readingFont'] as String?);
          textScale = ((json['textScale'] as num?)?.toDouble() ?? 1).clamp(
            0.9,
            1.4,
          );
          archiveWidth = (json['archiveWidth'] as num?)?.toDouble() ?? 244;
          archiveVisible = json['archiveVisible'] as bool? ?? true;
          inspectorVisible = json['inspectorVisible'] as bool? ?? true;
          inspectorWidth = (json['inspectorWidth'] as num?)?.toDouble() ?? 336;
          workspacePath = json['workspacePath'] as String?;
          recentWorkspacePaths =
              (json['recentWorkspacePaths'] as List? ?? const [])
                  .whereType<String>()
                  .where((path) => path.trim().isNotEmpty)
                  .take(8)
                  .toList(growable: false);
          pinnedSessionPaths = (json['pinnedSessionPaths'] as List? ?? const [])
              .whereType<String>()
              .take(24)
              .toList(growable: false);
          archivedSessionPaths =
              (json['archivedSessionPaths'] as List? ?? const [])
                  .whereType<String>()
                  .take(80)
                  .toList(growable: false);
          _layoutVersion = json['layoutVersion'] as int? ?? 0;
          if (_layoutVersion < 4) {
            themeMode = ThemeMode.dark;
            archiveWidth = 244;
            // The right-side Pi status and workspace surface is part of the
            // desktop layout now; users may still close it explicitly.
            inspectorVisible = true;
          }
          if (_layoutVersion < 5) {
            _layoutVersion = 5;
            await _save();
          }
        }
      }
    } on Object {
      // A missing or corrupt UI file must not affect Pi Session restore.
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _save();
  }

  Future<void> cycleThemeMode() {
    return setThemeMode(
      themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  Future<void> cycleDensity() async {
    density = density == PiDensity.compact
        ? PiDensity.standard
        : PiDensity.compact;
    notifyListeners();
    await _save();
  }

  Future<void> setReadingFont(PiReadingFont font) async {
    readingFont = font;
    notifyListeners();
    await _save();
  }

  void setTextScale(double scale, {bool persist = false}) {
    textScale = scale.clamp(0.9, 1.4);
    notifyListeners();
    _persist(persist);
  }

  Future<void> resetLayout() async {
    archiveWidth = 244;
    inspectorWidth = 336;
    archiveVisible = true;
    inspectorVisible = true;
    density = PiDensity.standard;
    notifyListeners();
    await _save();
  }

  void setArchiveWidth(double width, {bool persist = false}) {
    archiveWidth = width.clamp(220, 420);
    notifyListeners();
    _persist(persist);
  }

  Future<void> persistLayout() => _save();

  Future<void> toggleArchive() async {
    archiveVisible = !archiveVisible;
    notifyListeners();
    await _save();
  }

  Future<void> toggleInspector() async {
    inspectorVisible = !inspectorVisible;
    notifyListeners();
    await _save();
  }

  void setInspectorWidth(double width, {bool persist = false}) {
    inspectorWidth = width.clamp(300, 460);
    notifyListeners();
    _persist(persist);
  }

  Future<void> setWorkspacePath(String path) async {
    workspacePath = path;
    recentWorkspacePaths = <String>[
      path,
      ...recentWorkspacePaths.where((item) => item != path),
    ].take(8).toList(growable: false);
    notifyListeners();
    await _save();
  }

  Future<void> toggleSessionPinned(String path) async {
    pinnedSessionPaths = _toggle(pinnedSessionPaths, path, limit: 24);
    notifyListeners();
    await _save();
  }

  Future<void> toggleSessionArchived(String path) async {
    archivedSessionPaths = _toggle(archivedSessionPaths, path, limit: 80);
    if (archivedSessionPaths.contains(path)) {
      pinnedSessionPaths = pinnedSessionPaths
          .where((item) => item != path)
          .toList(growable: false);
    }
    notifyListeners();
    await _save();
  }

  static List<String> _toggle(
    List<String> values,
    String path, {
    required int limit,
  }) {
    if (values.contains(path)) {
      return values.where((item) => item != path).toList(growable: false);
    }
    return <String>[path, ...values].take(limit).toList(growable: false);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  void _persist(bool immediate) {
    if (immediate) {
      _saveTimer?.cancel();
      unawaited(_save());
      return;
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_save());
    });
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
          'themeMode': themeMode == ThemeMode.light ? 'light' : 'dark',
          'density': density == PiDensity.standard ? 'standard' : 'compact',
          'readingFont': readingFont.name,
          'textScale': textScale,
          'archiveWidth': archiveWidth,
          'archiveVisible': archiveVisible,
          'inspectorVisible': inspectorVisible,
          'inspectorWidth': inspectorWidth,
          'workspacePath': workspacePath,
          'recentWorkspacePaths': recentWorkspacePaths,
          'pinnedSessionPaths': pinnedSessionPaths,
          'archivedSessionPaths': archivedSessionPaths,
          'layoutVersion': 5,
        }),
      );
    } on Object {
      // UI preference persistence is best-effort.
    }
  }

  Future<File> _file() async {
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    if (Platform.isMacOS) {
      return File(
        '$home/Library/Application Support/Pi Desktop/ui_preferences.json',
      );
    }
    if (Platform.isWindows) {
      final appData =
          Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
      return File('$appData\\Pi Desktop\\ui_preferences.json');
    }
    return File('$home/.config/pi-desktop/ui_preferences.json');
  }
}
