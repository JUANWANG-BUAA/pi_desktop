import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'jsonl_framer.dart';

/// A response emitted by the Pi RPC process.
class PiRpcResponse {
  PiRpcResponse._({
    required this.id,
    required this.command,
    required this.success,
    required this.data,
    required this.error,
    required Map<String, dynamic> json,
  }) : json = Map.unmodifiable(json);

  factory PiRpcResponse.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    final command = json['command'];
    final success = json['success'];
    final id = json['id'];

    if (type != 'response' || command is! String || success is! bool) {
      throw const FormatException('Invalid Pi RPC response object.');
    }
    if (id != null && id is! String) {
      throw const FormatException('Pi RPC response id must be a string.');
    }

    return PiRpcResponse._(
      id: id as String?,
      command: command,
      success: success,
      data: json['data'],
      error: json['error'] as String?,
      json: json,
    );
  }

  final String? id;
  final String command;
  final bool success;
  final Object? data;
  final String? error;
  final Map<String, dynamic> json;
}

/// The process result exposed after Pi exits.
class PiRpcExit {
  const PiRpcExit(this.exitCode);

  final int exitCode;
}

/// Thin process client for the official Pi RPC JSONL protocol.
///
/// This class only frames commands, correlates responses, and forwards events.
/// It does not schedule prompts, execute tools, or maintain a session model.
class PiRpcClient {
  PiRpcClient._(this._process) {
    _done = _watchExit();
    _stdoutFramer = JsonlFramer(onLine: _handleStdoutLine);
    _listenToProcess();
  }

  /// Starts an official Pi RPC process.
  static Future<PiRpcClient> start({
    String executable = 'pi',
    List<String> arguments = const <String>['--mode', 'rpc'],
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: false,
    );
    return PiRpcClient._(process);
  }

  final Process _process;
  final Map<String, Completer<PiRpcResponse>> _pending =
      <String, Completer<PiRpcResponse>>{};
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _stderr = StreamController<String>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();
  late final JsonlFramer _stdoutFramer;
  late final Future<PiRpcExit> _done;

  var _nextRequestId = 0;
  var _isClosed = false;
  var _isClosing = false;
  Future<void> _writeTail = Future<void>.value();

  /// Non-response JSON objects from Pi, including asynchronous agent events.
  Stream<Map<String, dynamic>> get events => _events.stream;

  /// Pi stderr, kept separate from the JSONL protocol stream.
  Stream<String> get stderr => _stderr.stream;

  /// Framing, decoding, and protocol errors observed by this client.
  Stream<Object> get errors => _errors.stream;

  /// Completes when the child process exits and all pending requests are failed.
  Future<PiRpcExit> get done => _done;

  bool get isClosed => _isClosed;

  /// Sends one direct Pi RPC command and waits for its correlated response.
  Future<PiRpcResponse> sendCommand(
    String type, [
    Map<String, dynamic> fields = const <String, dynamic>{},
  ]) async {
    _ensureWritable();

    final id = 'pi-desktop-${_nextRequestId++}';
    final payload = <String, dynamic>{...fields, 'id': id, 'type': type};
    final completer = Completer<PiRpcResponse>();
    _pending[id] = completer;

    try {
      await _writeLine('${jsonEncode(payload)}\n');
    } on Object catch (error, stackTrace) {
      _pending.remove(id);
      completer.completeError(error, stackTrace);
    }

    return completer.future;
  }

  /// Closes stdin and terminates Pi if it does not exit normally.
  Future<PiRpcExit> close() async {
    if (_isClosed) {
      return _done;
    }
    if (!_isClosing) {
      _isClosing = true;
      try {
        await _writeTail;
        await _process.stdin.close();
      } on Object catch (error, stackTrace) {
        _reportError(error, stackTrace);
      }
      if (!_isClosed) {
        _process.kill(ProcessSignal.sigterm);
      }
    }
    return _done;
  }

  Future<void> _writeLine(String line) {
    final write = _writeTail.then<void>((_) async {
      _process.stdin.add(utf8.encode(line));
      await _process.stdin.flush();
    });
    _writeTail = write.catchError((Object _) {});
    return write;
  }

  void _listenToProcess() {
    _process.stdout.listen(
      _stdoutFramer.add,
      onError: (Object error, StackTrace stackTrace) {
        _reportError(error, stackTrace);
      },
      onDone: () {
        try {
          _stdoutFramer.close();
        } on Object catch (error, stackTrace) {
          _reportError(error, stackTrace);
        }
      },
    );

    utf8.decoder
        .bind(_process.stderr)
        .listen(
          _stderr.add,
          onError: (Object error, StackTrace stackTrace) {
            _reportError(error, stackTrace);
          },
        );
  }

  Future<PiRpcExit> _watchExit() async {
    final exitCode = await _process.exitCode;
    _isClosed = true;
    _rejectPending(StateError('Pi RPC process exited with code $exitCode.'));
    await Future.wait<void>(<Future<void>>[
      _events.close(),
      _stderr.close(),
      _errors.close(),
    ]);
    return PiRpcExit(exitCode);
  }

  void _handleStdoutLine(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        throw const FormatException('Pi RPC record must be a JSON object.');
      }
      final json = Map<String, dynamic>.from(decoded);
      if (json['type'] == 'response') {
        final id = json['id'];
        if (id is String) {
          final completer = _pending.remove(id);
          if (completer != null) {
            completer.complete(PiRpcResponse.fromJson(json));
            return;
          }
        }
      }
      _events.add(json);
    } on Object catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  void _reportError(Object error, [StackTrace? stackTrace]) {
    if (!_errors.isClosed) {
      _errors.addError(error, stackTrace);
    }
    _rejectPending(error, stackTrace);
    if (!_isClosed) {
      _process.kill(ProcessSignal.sigterm);
    }
  }

  void _rejectPending(Object error, [StackTrace? stackTrace]) {
    final pending = List<Completer<PiRpcResponse>>.from(_pending.values);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
  }

  void _ensureWritable() {
    if (_isClosed || _isClosing) {
      throw StateError('Pi RPC client is closed.');
    }
  }
}
