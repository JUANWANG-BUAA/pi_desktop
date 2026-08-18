import 'dart:async';

import 'package:flutter/foundation.dart';

import '../rpc/pi_rpc_client.dart';
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
    Map<String, String>? environment,
  }) : arguments = List.unmodifiable(arguments),
       environment = environment == null ? null : Map.unmodifiable(environment);

  final String executable;
  final List<String> arguments;
  final Map<String, String>? environment;

  PiRpcClient? _client;
  PiSessionProjection? _projection;
  StreamSubscription<PiJsonObject>? _extensionUiSubscription;
  final StreamController<PiJsonObject> _extensionUiRequests =
      StreamController<PiJsonObject>.broadcast();
  final Map<String, String> _extensionStatuses = <String, String>{};
  final Map<String, List<String>> _extensionWidgets = <String, List<String>>{};
  PiConnectionStatus _status = PiConnectionStatus.disconnected;
  String? _errorMessage;
  String? _extensionTitle;
  String? _extensionEditorText;
  var _isDisposed = false;

  PiConnectionStatus get status => _status;
  PiSessionProjection? get projection => _projection;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == PiConnectionStatus.connected;
  bool get isConnecting => _status == PiConnectionStatus.connecting;
  bool get isStreaming => _projection?.isStreaming ?? false;
  Stream<PiJsonObject> get extensionUiRequests => _extensionUiRequests.stream;
  Map<String, String> get extensionStatuses =>
      Map.unmodifiable(_extensionStatuses);
  Map<String, List<String>> get extensionWidgets =>
      Map.unmodifiable(_extensionWidgets);
  String? get extensionTitle => _extensionTitle;
  String? get extensionEditorText => _extensionEditorText;

  Future<void> connect() async {
    if (_status == PiConnectionStatus.connecting || isConnected) {
      return;
    }

    _setStatus(PiConnectionStatus.connecting);
    _errorMessage = null;
    _resetExtensionUiState();

    try {
      final client = await PiRpcClient.start(
        executable: executable,
        arguments: arguments,
        environment: environment,
      );
      _client = client;
      final projection = PiSessionProjection(client);
      _projection = projection;
      _extensionUiSubscription = client.events
          .where((event) => event['type'] == 'extension_ui_request')
          .listen(_handleExtensionUiRequest);
      unawaited(_watchProcess(client));
      await projection.load();

      if (identical(_client, client) && !client.isClosed) {
        _setStatus(PiConnectionStatus.connected);
      }
    } on Object catch (error) {
      await _extensionUiSubscription?.cancel();
      _extensionUiSubscription = null;
      final failedClient = _client;
      _client = null;
      _projection?.dispose();
      _projection = null;
      if (failedClient != null && !failedClient.isClosed) {
        await failedClient.close();
      }
      _errorMessage = error.toString();
      _setStatus(PiConnectionStatus.disconnected);
    }
  }

  /// Explicitly restarts the Pi process; no automatic retry is performed.
  Future<void> restart() async {
    await disconnect();
    await connect();
  }

  Future<void> disconnect() async {
    final client = _client;
    if (client == null) {
      _resetExtensionUiState();
      _setStatus(PiConnectionStatus.disconnected);
      return;
    }

    _setStatus(PiConnectionStatus.stopping);
    await _extensionUiSubscription?.cancel();
    _extensionUiSubscription = null;
    await client.close();
    _projection?.dispose();
    _projection = null;
    _client = null;
    _resetExtensionUiState();
    _setStatus(PiConnectionStatus.disconnected);
  }

  Future<PiRpcResponse> prompt(String message) {
    return _send('prompt', <String, dynamic>{'message': message});
  }

  Future<PiRpcResponse> steer(String message) {
    return _send('steer', <String, dynamic>{'message': message});
  }

  Future<PiRpcResponse> followUp(String message) {
    return _send('follow_up', <String, dynamic>{'message': message});
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

  Future<PiRpcResponse> setModel(String provider, String modelId) async {
    final response = await _send('set_model', <String, dynamic>{
      'provider': provider,
      'modelId': modelId,
    });
    await _projection?.load();
    return response;
  }

  Future<PiRpcResponse> cycleModel() async {
    final response = await _send('cycle_model');
    await _projection?.load();
    return response;
  }

  Future<PiRpcResponse> setThinkingLevel(String level) async {
    final response = await _send('set_thinking_level', <String, dynamic>{
      'level': level,
    });
    await _projection?.load();
    return response;
  }

  Future<PiRpcResponse> cycleThinkingLevel() async {
    final response = await _send('cycle_thinking_level');
    await _projection?.load();
    return response;
  }

  Future<PiRpcResponse> compact([String? customInstructions]) async {
    final fields = <String, dynamic>{};
    if (customInstructions != null) {
      fields['customInstructions'] = customInstructions;
    }
    final response = await _send('compact', fields);
    await _projection?.refreshSessionStats();
    return response;
  }

  Future<PiRpcResponse> setAutoCompaction(bool enabled) {
    return _send('set_auto_compaction', <String, dynamic>{'enabled': enabled});
  }

  Future<PiRpcResponse> setAutoRetry(bool enabled) {
    return _send('set_auto_retry', <String, dynamic>{'enabled': enabled});
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
    return _send('export_html', fields);
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
    unawaited(_extensionUiSubscription?.cancel());
    unawaited(_extensionUiRequests.close());
    final client = _client;
    _projection?.dispose();
    _projection = null;
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

  Future<PiRpcResponse> _send(
    String command, [
    Map<String, dynamic> fields = const <String, dynamic>{},
  ]) async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('Pi RPC is not connected.');
    }

    final response = await client.sendCommand(command, fields);
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

    _errorMessage = exit.exitCode == 0
        ? null
        : 'Pi RPC exited with code ${exit.exitCode}.';
    _setStatus(
      exit.exitCode == 0
          ? PiConnectionStatus.disconnected
          : PiConnectionStatus.crashed,
    );
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
