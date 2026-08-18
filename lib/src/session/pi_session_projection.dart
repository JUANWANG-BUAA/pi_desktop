import 'dart:async';

import 'package:flutter/foundation.dart';

import '../rpc/pi_rpc_client.dart';

typedef PiJsonObject = Map<String, dynamic>;

/// A rebuildable UI projection of data returned by Pi RPC.
///
/// This class intentionally does not own a conversation, tool, or session
/// store. Lists and partial text are discarded with the UI and are refreshed
/// from Pi after restart or authoritative `message_end` events.
class PiSessionProjection extends ChangeNotifier {
  PiSessionProjection(this._client) {
    _eventSubscription = _client.events.listen(_handleEvent);
    _errorSubscription = _client.errors.listen((error) {
      _lastError = error.toString();
      _notify();
    });
  }

  final PiRpcClient _client;
  late final StreamSubscription<PiJsonObject> _eventSubscription;
  late final StreamSubscription<Object> _errorSubscription;

  PiJsonObject? _state;
  List<PiJsonObject> _messages = const <PiJsonObject>[];
  PiJsonObject? _entries;
  PiJsonObject? _tree;
  List<PiJsonObject> _commands = const <PiJsonObject>[];
  String? _streamingText;
  String? _lastEventType;
  String? _lastError;
  var _isStreaming = false;
  var _isDisposed = false;

  PiJsonObject? get state => _state;
  List<PiJsonObject> get messages => List.unmodifiable(_messages);
  PiJsonObject? get entries => _entries;
  PiJsonObject? get tree => _tree;
  List<PiJsonObject> get commands => List.unmodifiable(_commands);
  String? get streamingText => _streamingText;
  String? get lastEventType => _lastEventType;
  String? get lastError => _lastError;
  bool get isStreaming => _isStreaming;

  /// Restores the current UI projection from Pi's authoritative RPC state.
  Future<void> load() async {
    final responses = await Future.wait(<Future<PiRpcResponse>>[
      _client.sendCommand('get_state'),
      _client.sendCommand('get_messages'),
      _client.sendCommand('get_entries'),
      _client.sendCommand('get_tree'),
      _client.sendCommand('get_commands'),
    ]);

    _state = _requireObject(responses[0], 'get_state');
    _messages = _readObjectList(
      _requireObject(responses[1], 'get_messages')['messages'],
    );
    _entries = _requireObject(responses[2], 'get_entries');
    _tree = _requireObject(responses[3], 'get_tree');
    _commands = _readObjectList(
      _requireObject(responses[4], 'get_commands')['commands'],
    );
    _isStreaming = _state?['isStreaming'] == true;
    _lastError = null;
    _notify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_eventSubscription.cancel());
    unawaited(_errorSubscription.cancel());
    super.dispose();
  }

  void _handleEvent(PiJsonObject event) {
    _lastEventType = event['type'] as String?;
    switch (_lastEventType) {
      case 'agent_start':
        _isStreaming = true;
      case 'agent_settled':
        _isStreaming = false;
        unawaited(_refreshState());
      case 'message_start':
        _handleMessageStart(event['message']);
      case 'message_update':
        _handleMessageUpdate(event['assistantMessageEvent']);
      case 'message_end':
        _streamingText = null;
        unawaited(_refreshMessages());
      case 'extension_error':
        _lastError = event['error'] as String? ?? 'Pi extension error';
    }
    _notify();
  }

  void _handleMessageStart(Object? rawMessage) {
    if (rawMessage is! Map) {
      return;
    }
    final message = Map<String, dynamic>.from(rawMessage);
    if (message['role'] == 'assistant') {
      _streamingText = '';
    }
  }

  void _handleMessageUpdate(Object? rawEvent) {
    if (rawEvent is! Map) {
      return;
    }
    final event = Map<String, dynamic>.from(rawEvent);
    if (event['type'] == 'text_delta' && event['delta'] is String) {
      _streamingText = '${_streamingText ?? ''}${event['delta']}';
    }
  }

  Future<void> _refreshMessages() async {
    try {
      final response = await _client.sendCommand('get_messages');
      _messages = _readObjectList(
        _requireObject(response, 'get_messages')['messages'],
      );
      _notify();
    } on Object catch (error) {
      _lastError = error.toString();
      _notify();
    }
  }

  Future<void> _refreshState() async {
    try {
      final response = await _client.sendCommand('get_state');
      _state = _requireObject(response, 'get_state');
      _isStreaming = _state?['isStreaming'] == true;
      _notify();
    } on Object catch (error) {
      _lastError = error.toString();
      _notify();
    }
  }

  PiJsonObject _requireObject(PiRpcResponse response, String command) {
    if (!response.success) {
      throw StateError(
        'Pi RPC command $command failed: ${response.error ?? 'unknown error'}',
      );
    }
    final data = response.data;
    if (data is! Map) {
      throw StateError(
        'Pi RPC command $command returned a non-object payload.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  List<PiJsonObject> _readObjectList(Object? value) {
    if (value is! List) {
      return const <PiJsonObject>[];
    }
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }
}
