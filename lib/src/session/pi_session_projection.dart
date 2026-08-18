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
  List<PiJsonObject> _availableModels = const <PiJsonObject>[];
  List<String> _thinkingLevels = const <String>[];
  PiJsonObject? _sessionStats;
  List<PiJsonObject> _toolEvents = const <PiJsonObject>[];
  List<PiJsonObject> _timelineEvents = const <PiJsonObject>[];
  List<String> _steeringQueue = const <String>[];
  List<String> _followUpQueue = const <String>[];
  String? _streamingText;
  String? _streamingThinking;
  String? _lastEventType;
  String? _lastError;
  var _isStreaming = false;
  var _isDisposed = false;

  PiJsonObject? get state => _state;
  List<PiJsonObject> get messages => List.unmodifiable(_messages);
  PiJsonObject? get entries => _entries;
  PiJsonObject? get tree => _tree;
  List<PiJsonObject> get commands => List.unmodifiable(_commands);
  List<PiJsonObject> get availableModels => List.unmodifiable(_availableModels);
  List<String> get thinkingLevels => List.unmodifiable(_thinkingLevels);
  PiJsonObject? get sessionStats => _sessionStats;
  List<PiJsonObject> get toolEvents => List.unmodifiable(_toolEvents);
  List<PiJsonObject> get timelineEvents => List.unmodifiable(_timelineEvents);
  List<String> get steeringQueue => List.unmodifiable(_steeringQueue);
  List<String> get followUpQueue => List.unmodifiable(_followUpQueue);
  String? get streamingText => _streamingText;
  String? get streamingThinking => _streamingThinking;
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
    _toolEvents = const <PiJsonObject>[];
    _timelineEvents = const <PiJsonObject>[];
    _steeringQueue = const <String>[];
    _followUpQueue = const <String>[];
    _streamingText = null;
    _streamingThinking = null;
    _lastEventType = null;
    _isStreaming = _state?['isStreaming'] == true;
    _lastError = null;
    _notify();

    await refreshModels();
    await refreshThinkingLevels();
    await refreshSessionStats();
  }

  Future<void> refreshModels() async {
    try {
      final response = await _client.sendCommand('get_available_models');
      _availableModels = _readObjectList(
        _requireObject(response, 'get_available_models')['models'],
      );
      _notify();
    } on Object catch (error) {
      _lastError = error.toString();
      _notify();
    }
  }

  Future<void> refreshThinkingLevels() async {
    try {
      final response = await _client.sendCommand(
        'get_available_thinking_levels',
      );
      _thinkingLevels = _readStringList(
        _requireObject(response, 'get_available_thinking_levels')['levels'],
      );
      _notify();
    } on Object catch (error) {
      _lastError = error.toString();
      _notify();
    }
  }

  Future<void> refreshSessionStats() async {
    try {
      final response = await _client.sendCommand('get_session_stats');
      _sessionStats = _requireObject(response, 'get_session_stats');
      _notify();
    } on Object catch (error) {
      _lastError = error.toString();
      _notify();
    }
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
        _streamingThinking = null;
        unawaited(_refreshMessages());
      case 'tool_execution_start':
      case 'tool_execution_update':
      case 'tool_execution_end':
        _upsertToolEvent(event);
      case 'queue_update':
        _steeringQueue = _readStringList(event['steering']);
        _followUpQueue = _readStringList(event['followUp']);
      case 'compaction_start':
      case 'compaction_end':
      case 'auto_retry_start':
      case 'auto_retry_end':
      case 'summarization_retry_scheduled':
      case 'summarization_retry_attempt_start':
      case 'summarization_retry_finished':
        _appendTimelineEvent(event);
        if (_lastEventType == 'compaction_end') {
          unawaited(_refreshMessages());
        }
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
      _streamingThinking = '';
    }
  }

  void _handleMessageUpdate(Object? rawEvent) {
    if (rawEvent is! Map) {
      return;
    }
    final event = Map<String, dynamic>.from(rawEvent);
    switch (event['type']) {
      case 'text_delta':
        if (event['delta'] is String) {
          _streamingText = '${_streamingText ?? ''}${event['delta']}';
        }
      case 'thinking_delta':
        if (event['delta'] is String) {
          _streamingThinking = '${_streamingThinking ?? ''}${event['delta']}';
        }
    }
  }

  void _upsertToolEvent(PiJsonObject event) {
    final toolCallId = event['toolCallId'];
    if (toolCallId is! String) {
      _appendTimelineEvent(event);
      return;
    }

    final index = _toolEvents.indexWhere(
      (item) => item['toolCallId'] == toolCallId,
    );
    final updated = List<PiJsonObject>.from(_toolEvents);
    if (index < 0) {
      updated.add(Map.unmodifiable(event));
    } else {
      updated[index] = Map.unmodifiable(event);
    }
    _toolEvents = updated.length > 40
        ? updated.sublist(updated.length - 40)
        : updated;
  }

  void _appendTimelineEvent(PiJsonObject event) {
    final updated = <PiJsonObject>[..._timelineEvents, Map.unmodifiable(event)];
    _timelineEvents = updated.length > 80
        ? updated.sublist(updated.length - 80)
        : updated;
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

  List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value.whereType<String>().toList(growable: false);
  }

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }
}
