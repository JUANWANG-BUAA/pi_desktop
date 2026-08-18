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

  /// True when Pi accepted the command but a Pi extension handler cancelled
  /// it (`fork` / `switch_session` respond `success: true` with
  /// `data.cancelled: true`). Callers must not treat this as a completed
  /// action.
  bool get cancelledByExtension {
    final payload = data;
    return payload is Map && payload['cancelled'] == true;
  }
}

/// Raised when Pi does not answer a correlated request in time.
class PiRpcTimeoutException implements Exception {
  PiRpcTimeoutException(this.command, this.timeout);

  final String command;
  final Duration timeout;

  @override
  String toString() =>
      'Pi RPC command "$command" did not respond within '
      '${timeout.inSeconds}s.';
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
    _events = StreamController<Map<String, dynamic>>.broadcast(
      onListen: _flushEventBuffer,
    );
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

  /// Default bound for one request/response round trip. Pi answers command
  /// acceptance quickly; long-running work (compaction, export) must pass an
  /// explicit longer timeout.
  static const defaultCommandTimeout = Duration(seconds: 60);

  static const _closeGracePeriod = Duration(seconds: 3);
  static const _terminateGracePeriod = Duration(seconds: 3);
  static const _maxBufferedEvents = 4096;

  final Process _process;
  final Map<String, Completer<PiRpcResponse>> _pending =
      <String, Completer<PiRpcResponse>>{};
  final Map<String, Timer> _pendingTimeouts = <String, Timer>{};
  late final StreamController<Map<String, dynamic>> _events;
  final StreamController<String> _stderr = StreamController<String>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();
  final List<Map<String, dynamic>> _bufferedEvents = <Map<String, dynamic>>[];
  late final JsonlFramer _stdoutFramer;
  late final Future<PiRpcExit> _done;

  var _nextRequestId = 0;
  var _isClosed = false;
  var _isClosing = false;
  var _hasEventListener = false;
  Future<void> _writeTail = Future<void>.value();

  /// Non-response JSON objects from Pi, including asynchronous agent events.
  /// Events emitted before the first listener are buffered and replayed, so
  /// nothing Pi says between process start and subscription is dropped.
  Stream<Map<String, dynamic>> get events => _events.stream;

  /// Pi stderr, kept separate from the JSONL protocol stream.
  Stream<String> get stderr => _stderr.stream;

  /// Framing, decoding, and protocol errors observed by this client.
  Stream<Object> get errors => _errors.stream;

  /// Completes when the child process exits and all pending requests are failed.
  Future<PiRpcExit> get done => _done;

  bool get isClosed => _isClosed;

  /// Sends one direct Pi RPC command and waits for its correlated response.
  /// The wait is bounded by [timeout] so an unresponsive Pi cannot hang the
  /// desktop forever; the Pi process itself is left untouched on timeout.
  Future<PiRpcResponse> sendCommand(
    String type, [
    Map<String, dynamic> fields = const <String, dynamic>{},
    Duration? timeout,
  ]) async {
    _ensureWritable();

    final id = 'pi-desktop-${_nextRequestId++}';
    final payload = <String, dynamic>{...fields, 'id': id, 'type': type};
    final completer = Completer<PiRpcResponse>();
    _pending[id] = completer;

    final limit = timeout ?? defaultCommandTimeout;
    _pendingTimeouts[id] = Timer(limit, () {
      _pendingTimeouts.remove(id);
      final pending = _pending.remove(id);
      if (pending != null && !pending.isCompleted) {
        pending.completeError(PiRpcTimeoutException(type, limit));
      }
    });

    try {
      await _writeLine('${jsonEncode(payload)}\n');
    } on Object catch (error, stackTrace) {
      _pending.remove(id);
      _cancelTimeout(id);
      completer.completeError(error, stackTrace);
    }

    return completer.future;
  }

  /// Responds to a Pi Extension UI dialog request.
  ///
  /// This is a direct `extension_ui_response` protocol record and does not
  /// create a second request/response command type.
  Future<void> sendExtensionUiResponse(
    String requestId, {
    String? value,
    bool? confirmed,
    bool cancelled = false,
  }) async {
    _ensureWritable();
    final payload = <String, dynamic>{
      'type': 'extension_ui_response',
      'id': requestId,
    };
    if (value != null) {
      payload['value'] = value;
    }
    if (confirmed != null) {
      payload['confirmed'] = confirmed;
    }
    if (cancelled) {
      payload['cancelled'] = true;
    }
    await _writeLine('${jsonEncode(payload)}\n');
  }

  /// Closes stdin and lets Pi finish on its own; only escalates to SIGTERM,
  /// then SIGKILL, after bounded grace periods, so shutdown cannot hang.
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
        final exited = await _awaitExit(_closeGracePeriod);
        if (exited == null && !_isClosed) {
          _process.kill(ProcessSignal.sigterm);
          final terminated = await _awaitExit(_terminateGracePeriod);
          if (terminated == null && !_isClosed) {
            _process.kill(ProcessSignal.sigkill);
          }
        }
      }
    }
    return _done;
  }

  Future<PiRpcExit?> _awaitExit(Duration limit) async {
    try {
      return await _done.timeout(limit);
    } on TimeoutException {
      return null;
    }
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
      (chunk) {
        try {
          _stdoutFramer.add(chunk);
        } on Object catch (error, stackTrace) {
          _reportError(error, stackTrace);
        }
      },
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

    // stderr is diagnostic-only: tolerate malformed bytes instead of letting a
    // decode error terminate the Pi session.
    const Utf8Decoder(allowMalformed: true)
        .bind(_process.stderr)
        .listen(
          _stderr.add,
          onError: (Object error, StackTrace stackTrace) {
            if (!_stderr.isClosed) {
              _stderr.add('[pi desktop] stderr decode error: $error');
            }
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
          _cancelTimeout(id);
          if (completer != null) {
            completer.complete(PiRpcResponse.fromJson(json));
            return;
          }
          // Late or duplicate response: nobody is waiting anymore. Surface
          // it as a diagnostic instead of leaking it into the event stream.
          _noteError(
            'Pi RPC response "$id" arrived without a pending request.',
          );
          return;
        }
        _noteError('Pi RPC response without a usable id was ignored.');
        return;
      }
      _emitEvent(json);
    } on Object catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  void _emitEvent(Map<String, dynamic> json) {
    if (_events.isClosed) {
      return;
    }
    if (!_hasEventListener && !_events.hasListener) {
      if (_bufferedEvents.length < _maxBufferedEvents) {
        _bufferedEvents.add(json);
      }
      return;
    }
    _events.add(json);
  }

  void _flushEventBuffer() {
    if (_hasEventListener || _events.isClosed) {
      return;
    }
    _hasEventListener = true;
    for (final event in _bufferedEvents) {
      if (_events.isClosed) {
        break;
      }
      _events.add(event);
    }
    _bufferedEvents.clear();
  }

  /// Diagnostics that must not kill the Pi process.
  void _noteError(Object error) {
    if (!_errors.isClosed) {
      _errors.add(error);
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
    for (final timer in _pendingTimeouts.values) {
      timer.cancel();
    }
    _pendingTimeouts.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
  }

  void _cancelTimeout(String id) {
    _pendingTimeouts.remove(id)?.cancel();
  }

  void _ensureWritable() {
    if (_isClosed || _isClosing) {
      throw StateError('Pi RPC client is closed.');
    }
  }
}
