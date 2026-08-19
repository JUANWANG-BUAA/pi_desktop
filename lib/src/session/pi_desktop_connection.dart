import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../rpc/pi_rpc_client.dart';
import 'pi_baseline.dart';
import 'pi_session_projection.dart';

enum PiConnectionStatus {
  disconnected,
  connecting,
  connected,
  stopping,
  crashed,
}

/// Owns only the Pi process connection and forwards official RPC commands.
///
/// It does not decide when Pi should continue, retry, compact, or execute a
/// tool. Those semantics remain in Pi; the UI invokes the direct commands.
class PiDesktopConnection extends ChangeNotifier {
  PiDesktopConnection({
    this.executable = 'pi',
    List<String> arguments = const <String>[
      '--mode',
      'rpc',
      '--continue',
      '--no-approve',
    ],
    String? workingDirectory,
    Map<String, String>? environment,
  }) : arguments = List.unmodifiable(arguments),
       _workingDirectory = workingDirectory ?? _defaultWorkingDirectory(),
       environment = environment == null ? null : Map.unmodifiable(environment);

  final String executable;
  final List<String> arguments;
  String _workingDirectory;
  final Map<String, String>? environment;

  /// Compaction and export run real model/file work inside Pi before they
  /// respond; give them a longer bound than ordinary command acceptance.
  static const _longCommandTimeout = Duration(minutes: 5);

  PiRpcClient? _client;
  PiSessionProjection? _projection;
  StreamSubscription<PiJsonObject>? _extensionUiSubscription;
  StreamSubscription<String>? _stderrSubscription;
  String? _resolvedExecutable;
  String? _runtimeVersion;
  final StreamController<PiJsonObject> _extensionUiRequests =
      StreamController<PiJsonObject>.broadcast();
  final Map<String, String> _extensionStatuses = <String, String>{};
  final Map<String, List<String>> _extensionWidgets = <String, List<String>>{};
  final List<String> _stderrLines = <String>[];
  PiConnectionStatus _status = PiConnectionStatus.disconnected;
  String? _errorMessage;
  String? _extensionTitle;
  String? _extensionEditorText;
  var _isDisposed = false;
  var _isOperating = false;
  Timer? _stderrNotifyTimer;

  static String _defaultWorkingDirectory() {
    // AppKit launches opened macOS apps with `/` as cwd. That is not a useful
    // project default and can accidentally expose the whole filesystem to a
    // direct Pi session. Prefer an explicit non-root launch directory, then
    // the user's home; persisted workspace preference still wins in app.dart.
    final launchedFrom = Platform.environment['PWD']?.trim();
    if (launchedFrom != null &&
        launchedFrom.isNotEmpty &&
        launchedFrom != '/' &&
        Directory(launchedFrom).existsSync()) {
      return launchedFrom;
    }
    final home =
        (Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'])
            ?.trim();
    if (home != null && home.isNotEmpty && Directory(home).existsSync()) {
      return home;
    }
    return Directory.current.path;
  }

  PiConnectionStatus get status => _status;
  PiSessionProjection? get projection => _projection;
  String get workingDirectory => _workingDirectory;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == PiConnectionStatus.connected;
  bool get isConnecting => _status == PiConnectionStatus.connecting;
  bool get isStreaming => _projection?.isStreaming ?? false;
  Stream<PiJsonObject> get extensionUiRequests => _extensionUiRequests.stream;
  Map<String, String> get extensionStatuses =>
      Map.unmodifiable(_extensionStatuses);
  Map<String, List<String>> get extensionWidgets =>
      Map.unmodifiable(_extensionWidgets);
  List<String> get stderrLines => List.unmodifiable(_stderrLines);

  /// Absolute or PATH name actually spawned after `PI_DESKTOP_RUNTIME`.
  String get runtimeExecutable => _resolvedExecutable ?? executable;

  /// `pi --version` of [runtimeExecutable], set after a successful gate.
  String? get runtimeVersion => _runtimeVersion;
  String? get extensionTitle => _extensionTitle;
  String? get extensionEditorText => _extensionEditorText;

  /// Connects to the official Pi RPC process. Concurrent connect/restart/
  /// reconnect attempts are dropped instead of racing two child processes.
  Future<void> connect() => _guarded(_connect);

  Future<void> _connect() async {
    if (_status == PiConnectionStatus.connecting || isConnected) {
      return;
    }

    _setStatus(PiConnectionStatus.connecting);
    _errorMessage = null;
    _resetExtensionUiState();
    _stderrLines.clear();
    _runtimeVersion = null;

    try {
      final resolved = PiRuntime.resolveExecutable(executable);
      _resolvedExecutable = resolved;
      PiRuntime.enforceBaseline(resolved);
      _runtimeVersion = PiRuntime.shouldEnforceBaseline(resolved)
          ? piBaselineVersion
          : PiRuntime.readVersion(resolved);
      final client = await PiRpcClient.start(
        executable: resolved,
        arguments: arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      );
      _client = client;
      final projection = PiSessionProjection(client);
      _bindProjection(projection);
      _extensionUiSubscription = client.events
          .where((event) => event['type'] == 'extension_ui_request')
          .listen(_handleExtensionUiRequest);
      _stderrSubscription = client.stderr.listen(_handleStderr);
      unawaited(_watchProcess(client));
      await projection.load();

      if (identical(_client, client) && !client.isClosed) {
        _setStatus(PiConnectionStatus.connected);
      }
    } on Object catch (error) {
      await _tearDownClient(closeClient: true);
      _errorMessage = error.toString();
      _setStatus(PiConnectionStatus.disconnected);
    }
  }

  void applyWorkingDirectory(String directory) {
    final path = directory.trim();
    if (path.isEmpty || isConnected || isConnecting) {
      return;
    }
    if (path == _workingDirectory) {
      return;
    }
    _workingDirectory = path;
    _notify();
  }

  /// Restarts the official Pi RPC process in a different working directory.
  /// Pi owns the session files in that folder; this is process cwd, not a second store.
  Future<void> reconnectIn(String directory) {
    return _guarded(() async {
      final path = directory.trim();
      if (path.isEmpty) {
        return;
      }
      if (path == _workingDirectory && isConnected) {
        return;
      }
      await disconnect();
      _workingDirectory = path;
      _notify();
      await _connect();
    });
  }

  Future<void> restart() {
    return _guarded(() async {
      await disconnect();
      await _connect();
    });
  }

  Future<void> _guarded(Future<void> Function() action) async {
    if (_isDisposed || _isOperating) {
      return;
    }
    _isOperating = true;
    try {
      await action();
    } finally {
      _isOperating = false;
    }
  }

  Future<void> disconnect() async {
    final client = _client;
    if (client == null) {
      _resetExtensionUiState();
      _setStatus(PiConnectionStatus.disconnected);
      return;
    }

    _setStatus(PiConnectionStatus.stopping);
    await _tearDownClient(closeClient: true);
    _setStatus(PiConnectionStatus.disconnected);
  }

  Future<PiRpcResponse> prompt(
    String message, {
    List<PiJsonObject> images = const <PiJsonObject>[],
  }) {
    return _send('prompt', _messageFields(message, images));
  }

  Future<PiRpcResponse> steer(
    String message, {
    List<PiJsonObject> images = const <PiJsonObject>[],
  }) {
    return _send('steer', _messageFields(message, images));
  }

  Future<PiRpcResponse> followUp(
    String message, {
    List<PiJsonObject> images = const <PiJsonObject>[],
  }) {
    return _send('follow_up', _messageFields(message, images));
  }

  Future<PiRpcResponse> abort() => _send('abort');

  Future<void> respondToExtensionUi(
    String requestId, {
    String? value,
    bool? confirmed,
    bool cancelled = false,
  }) async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('Pi RPC is not connected.');
    }
    await client.sendExtensionUiResponse(
      requestId,
      value: value,
      confirmed: confirmed,
      cancelled: cancelled,
    );
  }

  Future<PiRpcResponse> newSession() => _sessionCommand('new_session');

  Future<PiRpcResponse> switchSession(String sessionPath) {
    return _sessionCommand('switch_session', <String, dynamic>{
      'sessionPath': sessionPath,
    });
  }

  Future<PiRpcResponse> fork(String entryId) {
    return _sessionCommand('fork', <String, dynamic>{'entryId': entryId});
  }

  Future<PiRpcResponse> clone() => _sessionCommand('clone');

  Future<PiRpcResponse> setSessionName(String name) async {
    final response = await _send('set_session_name', <String, dynamic>{
      'name': name,
    });
    if (response.success) {
      _projection?.applyStateValue('sessionName', name);
      unawaited(_projection?.refreshState());
    }
    return response;
  }

  Future<PiRpcResponse> setModel(String provider, String modelId) async {
    final response = await _send('set_model', <String, dynamic>{
      'provider': provider,
      'modelId': modelId,
    });
    if (response.success) {
      _projection?.applyModel(response.data);
      unawaited(_syncModelChrome());
    }
    return response;
  }

  Future<PiRpcResponse> cycleModel() async {
    final response = await _send('cycle_model');
    if (response.success) {
      _projection?.applyModel(response.data);
      final data = response.data;
      if (data is Map && data['thinkingLevel'] is String) {
        _projection?.applyThinkingLevel(data['thinkingLevel'] as String);
      }
      unawaited(_syncModelChrome());
    }
    return response;
  }

  Future<PiRpcResponse> setThinkingLevel(String level) async {
    final response = await _send('set_thinking_level', <String, dynamic>{
      'level': level,
    });
    if (response.success) {
      _projection?.applyThinkingLevel(level);
      unawaited(_projection?.refreshState());
    }
    return response;
  }

  Future<PiRpcResponse> cycleThinkingLevel() async {
    final response = await _send('cycle_thinking_level');
    if (response.success) {
      final data = response.data;
      if (data is Map && data['level'] is String) {
        _projection?.applyThinkingLevel(data['level'] as String);
      }
      unawaited(_projection?.refreshState());
    }
    return response;
  }

  Future<PiRpcResponse> setSteeringMode(String mode) async {
    final response = await _send('set_steering_mode', <String, dynamic>{
      'mode': mode,
    });
    if (response.success) {
      _projection?.applyStateValue('steeringMode', mode);
      unawaited(_projection?.refreshState());
    }
    return response;
  }

  Future<PiRpcResponse> setFollowUpMode(String mode) async {
    final response = await _send('set_follow_up_mode', <String, dynamic>{
      'mode': mode,
    });
    if (response.success) {
      _projection?.applyStateValue('followUpMode', mode);
      unawaited(_projection?.refreshState());
    }
    return response;
  }

  Future<PiRpcResponse> compact([String? customInstructions]) async {
    final fields = <String, dynamic>{};
    if (customInstructions != null) {
      fields['customInstructions'] = customInstructions;
    }
    final response = await _send('compact', fields, _longCommandTimeout);
    await _projection?.refreshSessionStats();
    return response;
  }

  Future<PiRpcResponse> setAutoCompaction(bool enabled) async {
    final response = await _send('set_auto_compaction', <String, dynamic>{
      'enabled': enabled,
    });
    if (response.success) {
      _projection?.applyFlag('autoCompactionEnabled', enabled);
      unawaited(_projection?.refreshState());
    }
    return response;
  }

  Future<PiRpcResponse> setAutoRetry(bool enabled) async {
    final response = await _send('set_auto_retry', <String, dynamic>{
      'enabled': enabled,
    });
    if (response.success) {
      unawaited(_projection?.refreshState());
    }
    return response;
  }

  Future<PiRpcResponse> abortRetry() => _send('abort_retry');

  Future<PiRpcResponse> getSessionStats() async {
    final response = await _send('get_session_stats');
    await _projection?.refreshSessionStats();
    return response;
  }

  Future<PiRpcResponse> exportHtml([String? outputPath]) {
    final fields = <String, dynamic>{};
    if (outputPath != null) {
      fields['outputPath'] = outputPath;
    }
    return _send('export_html', fields, _longCommandTimeout);
  }

  Future<PiRpcResponse> _sessionCommand(
    String command, [
    Map<String, dynamic> fields = const <String, dynamic>{},
  ]) async {
    final response = await _send(command, fields);
    if (response.success) {
      await _projection?.load();
    }
    return response;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stderrNotifyTimer?.cancel();
    unawaited(_extensionUiSubscription?.cancel());
    unawaited(_stderrSubscription?.cancel());
    unawaited(_extensionUiRequests.close());
    final client = _client;
    _unbindProjection();
    _client = null;
    if (client != null) {
      unawaited(client.close());
    }
    super.dispose();
  }

  void _handleExtensionUiRequest(PiJsonObject request) {
    final method = request['method'];
    switch (method) {
      case 'setStatus':
        final key = request['statusKey'];
        if (key is String) {
          final text = request['statusText'];
          if (text is String) {
            _extensionStatuses[key] = text;
          } else {
            _extensionStatuses.remove(key);
          }
        }
        _notify();
      case 'setWidget':
        final key = request['widgetKey'];
        if (key is String) {
          final lines = request['widgetLines'];
          if (lines is List) {
            _extensionWidgets[key] = lines.whereType<String>().toList();
          } else {
            _extensionWidgets.remove(key);
          }
        }
        _notify();
      case 'setTitle':
        _extensionTitle = request['title'] as String?;
        _notify();
      case 'set_editor_text':
        _extensionEditorText = request['text'] as String? ?? '';
        _notify();
      case 'notify':
      case 'select':
      case 'confirm':
      case 'input':
      case 'editor':
        _extensionUiRequests.add(request);
    }
  }

  void _handleStderr(String chunk) {
    for (final line in chunk.split('\n')) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) {
        continue;
      }
      _stderrLines.add(trimmed);
    }
    if (_stderrLines.length > 400) {
      _stderrLines.removeRange(0, _stderrLines.length - 400);
    }
    _stderrNotifyTimer ??= Timer(const Duration(milliseconds: 120), () {
      _stderrNotifyTimer = null;
      _notify();
    });
  }

  Future<void> _syncModelChrome() async {
    final projection = _projection;
    if (projection == null) {
      return;
    }
    await projection.refreshThinkingLevels(notify: false);
    await projection.refreshState();
  }

  Future<PiRpcResponse> _send(
    String command, [
    Map<String, dynamic> fields = const <String, dynamic>{},
    Duration? timeout,
  ]) async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('Pi RPC is not connected.');
    }

    final response = await client.sendCommand(command, fields, timeout);
    if (!response.success) {
      _errorMessage =
          'Pi RPC command $command failed: ${response.error ?? 'unknown error'}';
      _notify();
    }
    return response;
  }

  Future<void> _watchProcess(PiRpcClient client) async {
    final exit = await client.done;
    if (!identical(_client, client) || _isDisposed) {
      return;
    }

    await _tearDownClient();
    if (exit.exitCode == 0) {
      _errorMessage = null;
      _setStatus(PiConnectionStatus.disconnected);
      return;
    }
    final tail = _stderrTail(24);
    _errorMessage = tail.isEmpty
        ? 'Pi RPC exited with code ${exit.exitCode}.'
        : 'Pi RPC exited with code ${exit.exitCode}.\n$tail';
    await _persistCrashLog(exit.exitCode, tail);
    _setStatus(PiConnectionStatus.crashed);
  }

  String _stderrTail(int maxLines) {
    if (_stderrLines.isEmpty) {
      return '';
    }
    final start = _stderrLines.length > maxLines
        ? _stderrLines.length - maxLines
        : 0;
    return _stderrLines.sublist(start).join('\n');
  }

  Future<void> _persistCrashLog(int exitCode, String tail) async {
    try {
      final file = await _crashLogFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        'exitCode: $exitCode\n'
        'executable: $runtimeExecutable\n'
        'version: ${_runtimeVersion ?? 'unknown'}\n'
        'cwd: $workingDirectory\n'
        '\n$tail\n',
      );
    } on Object {
      // Crash persistence is diagnostic-only and must not affect Pi.
    }
  }

  Future<File> _crashLogFile() async {
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    if (Platform.isMacOS) {
      return File('$home/Library/Logs/Pi Desktop/last_pi_crash.log');
    }
    if (Platform.isWindows) {
      final appData =
          Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
      return File('$appData\\Pi Desktop\\last_pi_crash.log');
    }
    return File('$home/.local/share/pi-desktop/last_pi_crash.log');
  }

  void _bindProjection(PiSessionProjection projection) {
    _unbindProjection();
    _projection = projection;
  }

  void _unbindProjection() {
    _projection?.dispose();
    _projection = null;
  }

  Future<void> _tearDownClient({bool closeClient = false}) async {
    await _extensionUiSubscription?.cancel();
    _extensionUiSubscription = null;
    await _stderrSubscription?.cancel();
    _stderrSubscription = null;
    final client = _client;
    _unbindProjection();
    _client = null;
    _resetExtensionUiState();
    if (closeClient && client != null && !client.isClosed) {
      await client.close();
    }
  }

  Map<String, dynamic> _messageFields(
    String message,
    List<PiJsonObject> images,
  ) {
    final fields = <String, dynamic>{'message': message};
    if (images.isNotEmpty) {
      fields['images'] = images;
    }
    return fields;
  }

  void _setStatus(PiConnectionStatus status) {
    _status = status;
    _notify();
  }

  void _resetExtensionUiState() {
    _extensionStatuses.clear();
    _extensionWidgets.clear();
    _extensionTitle = null;
    _extensionEditorText = null;
  }

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }
}
