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
  PiConnectionStatus _status = PiConnectionStatus.disconnected;
  String? _errorMessage;
  var _isDisposed = false;

  PiConnectionStatus get status => _status;
  PiSessionProjection? get projection => _projection;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == PiConnectionStatus.connected;
  bool get isConnecting => _status == PiConnectionStatus.connecting;
  bool get isStreaming => _projection?.isStreaming ?? false;

  Future<void> connect() async {
    if (_status == PiConnectionStatus.connecting || isConnected) {
      return;
    }

    _setStatus(PiConnectionStatus.connecting);
    _errorMessage = null;

    try {
      final client = await PiRpcClient.start(
        executable: executable,
        arguments: arguments,
        environment: environment,
      );
      _client = client;
      final projection = PiSessionProjection(client);
      _projection = projection;
      unawaited(_watchProcess(client));
      await projection.load();

      if (identical(_client, client) && !client.isClosed) {
        _setStatus(PiConnectionStatus.connected);
      }
    } on Object catch (error) {
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
      _setStatus(PiConnectionStatus.disconnected);
      return;
    }

    _setStatus(PiConnectionStatus.stopping);
    await client.close();
    _projection?.dispose();
    _projection = null;
    _client = null;
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

  @override
  void dispose() {
    _isDisposed = true;
    final client = _client;
    _projection?.dispose();
    _projection = null;
    _client = null;
    if (client != null) {
      unawaited(client.close());
    }
    super.dispose();
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

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }
}
