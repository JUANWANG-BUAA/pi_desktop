import 'dart:async';

import 'package:flutter/foundation.dart';

import '../rpc/pi_rpc_client.dart';

typedef PiJsonObject = Map<String, dynamic>;

enum PiTranscriptKind { message, liveTool, timeline, streaming }

enum _NotifyKind { stream, chrome, structure }

/// A rebuildable row in the Transcript. It is derived from Pi RPC data and is
/// discarded with the UI; it is not a second conversation store.
class PiTranscriptItem {
  const PiTranscriptItem._({
    required this.kind,
    this.data,
    this.streamingText,
    this.streamingThinking,
  });

  factory PiTranscriptItem.message(PiJsonObject message) {
    return PiTranscriptItem._(kind: PiTranscriptKind.message, data: message);
  }

  factory PiTranscriptItem.liveTool(PiJsonObject event) {
    return PiTranscriptItem._(kind: PiTranscriptKind.liveTool, data: event);
  }

  factory PiTranscriptItem.timeline(PiJsonObject event) {
    return PiTranscriptItem._(kind: PiTranscriptKind.timeline, data: event);
  }

  factory PiTranscriptItem.streaming({required String text, String? thinking}) {
    return PiTranscriptItem._(
      kind: PiTranscriptKind.streaming,
      streamingText: text,
      streamingThinking: thinking,
    );
  }

  final PiTranscriptKind kind;
  final PiJsonObject? data;
  final String? streamingText;
  final String? streamingThinking;
}

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
      _notify(_NotifyKind.chrome);
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
  List<PiJsonObject> _forkMessages = const <PiJsonObject>[];
  List<String> _thinkingLevels = const <String>[];
  PiJsonObject? _sessionStats;
  List<PiJsonObject> _toolEvents = const <PiJsonObject>[];
  List<PiJsonObject> _timelineEvents = const <PiJsonObject>[];
  List<String> _steeringQueue = const <String>[];
  List<String> _followUpQueue = const <String>[];
  String? _streamingText;
  String? _streamingThinking;
  String? _bashOutput;
  StringBuffer? _streamingTextBuffer;
  StringBuffer? _streamingThinkingBuffer;
  StringBuffer? _bashOutputBuffer;
  String? _lastEventType;
  String? _lastError;
  var _isStreaming = false;
  var _isDisposed = false;
  var _structureEpoch = 0;
  var _chromeEpoch = 0;
  var _coalesceScheduled = false;
  Timer? _coalesceTimer;
  List<PiTranscriptItem>? _documentsCache;

  PiJsonObject? get state => _state;
  List<PiJsonObject> get messages => List.unmodifiable(_messages);
  PiJsonObject? get entries => _entries;
  PiJsonObject? get tree => _tree;
  List<PiJsonObject> get commands => List.unmodifiable(_commands);
  List<PiJsonObject> get availableModels => List.unmodifiable(_availableModels);
  List<PiJsonObject> get forkMessages => List.unmodifiable(_forkMessages);
  List<String> get thinkingLevels => List.unmodifiable(_thinkingLevels);
  PiJsonObject? get sessionStats => _sessionStats;
  List<PiJsonObject> get toolEvents => List.unmodifiable(_toolEvents);
  List<PiJsonObject> get timelineEvents => List.unmodifiable(_timelineEvents);
  List<String> get steeringQueue => List.unmodifiable(_steeringQueue);
  List<String> get followUpQueue => List.unmodifiable(_followUpQueue);
  String? get streamingText => _streamingText;
  String? get streamingThinking => _streamingThinking;
  String? get bashOutput => _bashOutput;
  String? get lastEventType => _lastEventType;
  String? get lastError => _lastError;
  bool get isStreaming => _isStreaming;
  int get structureEpoch => _structureEpoch;
  int get chromeEpoch => _chromeEpoch;

  /// Chronological Transcript rows rebuilt from Pi messages and live events.
  List<PiTranscriptItem> get documents {
    final cached = _documentsCache;
    if (cached != null) {
      return cached;
    }
    final items = <PiTranscriptItem>[];
    final knownToolIds = <String>{};

    for (final message in _messages) {
      items.add(PiTranscriptItem.message(message));
      knownToolIds.addAll(_toolCallIdsIn(message));
    }

    for (final event in _toolEvents) {
      final id = event['toolCallId'];
      if (id is String && knownToolIds.contains(id)) {
        continue;
      }
      items.add(PiTranscriptItem.liveTool(event));
    }

    for (final event in _timelineEvents) {
      items.add(PiTranscriptItem.timeline(event));
    }

    _documentsCache = items;
    return items;
  }

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
    _bashOutput = null;
    _streamingTextBuffer = null;
    _streamingThinkingBuffer = null;
    _bashOutputBuffer = null;
    _lastEventType = null;
    _isStreaming = _state?['isStreaming'] == true;
    _lastError = null;
    _notify(_NotifyKind.structure);

    await Future.wait(<Future<void>>[
      refreshModels(notify: false),
      refreshThinkingLevels(notify: false),
      refreshSessionStats(notify: false),
      refreshForkMessages(notify: false),
    ]);
    _notify(_NotifyKind.chrome);
  }

  Future<void> refreshState() => _refreshState();

  void applyModel(Object? data) {
    if (data is! Map) {
      return;
    }
    final raw = Map<String, dynamic>.from(data);
    final model = raw['model'] is Map
        ? Map<String, dynamic>.from(raw['model'] as Map)
        : raw;
    if (model['id'] is! String) {
      return;
    }
    final state = Map<String, dynamic>.from(_state ?? {});
    state['model'] = model;
    _state = state;
    _notify(_NotifyKind.chrome);
  }

  void applyThinkingLevel(String level) {
    final state = Map<String, dynamic>.from(_state ?? {});
    state['thinkingLevel'] = level;
    _state = state;
    _notify(_NotifyKind.chrome);
  }

  void applyFlag(String key, bool value) {
    applyStateValue(key, value);
  }

  void applyStateValue(String key, Object value) {
    final state = Map<String, dynamic>.from(_state ?? {});
    state[key] = value;
    _state = state;
    _notify(_NotifyKind.chrome);
  }

  Future<void> refreshModels({bool notify = true}) async {
    try {
      final response = await _client.sendCommand('get_available_models');
      _availableModels = _readObjectList(
        _requireObject(response, 'get_available_models')['models'],
      );
      if (notify) {
        _notify(_NotifyKind.chrome);
      }
    } on Object catch (error) {
      _lastError = error.toString();
      if (notify) {
        _notify(_NotifyKind.chrome);
      }
    }
  }

  Future<void> refreshThinkingLevels({bool notify = true}) async {
    try {
      final response = await _client.sendCommand(
        'get_available_thinking_levels',
      );
      _thinkingLevels = _readStringList(
        _requireObject(response, 'get_available_thinking_levels')['levels'],
      );
      if (notify) {
        _notify(_NotifyKind.chrome);
      }
    } on Object catch (error) {
      _lastError = error.toString();
      if (notify) {
        _notify(_NotifyKind.chrome);
      }
    }
  }

  Future<void> refreshSessionStats({bool notify = true}) async {
    try {
      final response = await _client.sendCommand('get_session_stats');
      _sessionStats = _requireObject(response, 'get_session_stats');
      if (notify) {
        _notify(_NotifyKind.chrome);
      }
    } on Object catch (error) {
      _lastError = error.toString();
      if (notify) {
        _notify(_NotifyKind.chrome);
      }
    }
  }

  Future<void> refreshForkMessages({bool notify = true}) async {
    try {
      final response = await _client.sendCommand('get_fork_messages');
      _forkMessages = _readObjectList(
        _requireObject(response, 'get_fork_messages')['messages'],
      );
      if (notify) {
        _notify(_NotifyKind.chrome);
      }
    } on Object catch (error) {
      _lastError = error.toString();
      if (notify) {
        _notify(_NotifyKind.chrome);
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _coalesceTimer?.cancel();
    unawaited(_eventSubscription.cancel());
    unawaited(_errorSubscription.cancel());
    super.dispose();
  }

  void _handleEvent(PiJsonObject event) {
    _lastEventType = event['type'] as String?;
    var kind = _NotifyKind.structure;
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
        kind = _NotifyKind.stream;
      case 'message_end':
        _streamingText = null;
        _streamingThinking = null;
        _streamingTextBuffer = null;
        _streamingThinkingBuffer = null;
        final ended = event['message'];
        if (ended is Map) {
          _messages = <PiJsonObject>[
            ..._messages,
            Map<String, dynamic>.from(ended),
          ];
        }
        unawaited(_refreshMessages());
      case 'tool_execution_start':
        _upsertToolEvent(event);
      case 'tool_execution_update':
        _upsertToolEvent(event);
        kind = _NotifyKind.stream;
      case 'tool_execution_end':
        _upsertToolEvent(event);
      case 'bash_execution_update':
        final delta = event['delta'];
        if (delta is String) {
          (_bashOutputBuffer ??= StringBuffer(_bashOutput ?? '')).write(delta);
        }
        kind = _NotifyKind.stream;
      case 'queue_update':
        _steeringQueue = _readStringList(event['steering']);
        _followUpQueue = _readStringList(event['followUp']);
        kind = _NotifyKind.chrome;
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
          unawaited(refreshSessionStats());
        }
      case 'extension_error':
        _lastError = event['error'] as String? ?? 'Pi extension error';
        _appendTimelineEvent(event);
    }
    _notify(kind);
  }

  void _handleMessageStart(Object? rawMessage) {
    if (rawMessage is! Map) {
      return;
    }
    final message = Map<String, dynamic>.from(rawMessage);
    if (message['role'] == 'assistant') {
      _streamingText = '';
      _streamingThinking = '';
      _streamingTextBuffer = StringBuffer();
      _streamingThinkingBuffer = StringBuffer();
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
          (_streamingTextBuffer ??= StringBuffer(
            _streamingText ?? '',
          )).write(event['delta']);
        }
      case 'thinking_delta':
        if (event['delta'] is String) {
          (_streamingThinkingBuffer ??= StringBuffer(
            _streamingThinking ?? '',
          )).write(event['delta']);
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
      _notify(_NotifyKind.structure);
    } on Object catch (error) {
      _lastError = error.toString();
      _notify(_NotifyKind.chrome);
    }
  }

  Future<void> _refreshState() async {
    try {
      final response = await _client.sendCommand('get_state');
      _state = _requireObject(response, 'get_state');
      _isStreaming = _state?['isStreaming'] == true;
      _notify(_NotifyKind.chrome);
    } on Object catch (error) {
      _lastError = error.toString();
      _notify(_NotifyKind.chrome);
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

  Set<String> _toolCallIdsIn(PiJsonObject message) {
    final ids = <String>{};
    final toolCallId = message['toolCallId'];
    if (toolCallId is String) {
      ids.add(toolCallId);
    }
    final content = message['content'];
    if (content is List) {
      for (final block in content.whereType<Map>()) {
        final id = block['id'];
        if (block['type'] == 'toolCall' && id is String) {
          ids.add(id);
        }
      }
    }
    return ids;
  }

  void _notify(_NotifyKind kind) {
    if (_isDisposed) {
      return;
    }
    if (kind == _NotifyKind.stream) {
      _scheduleCoalesced();
      return;
    }
    _coalesceTimer?.cancel();
    _coalesceScheduled = false;
    _flushStreamingBuffers();
    _documentsCache = null;
    _chromeEpoch++;
    if (kind == _NotifyKind.structure) {
      _structureEpoch++;
    }
    notifyListeners();
  }

  void _scheduleCoalesced() {
    if (_coalesceScheduled) {
      return;
    }
    _coalesceScheduled = true;
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(const Duration(milliseconds: 16), _flushCoalesced);
  }

  void _flushCoalesced() {
    if (!_coalesceScheduled || _isDisposed) {
      return;
    }
    _coalesceScheduled = false;
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    _flushStreamingBuffers();
    notifyListeners();
  }

  /// Token updates are append-only until the next frame. This avoids copying
  /// the accumulated transcript for every incoming delta in a long response.
  void _flushStreamingBuffers() {
    final text = _streamingTextBuffer;
    if (text != null) {
      _streamingText = text.toString();
    }
    final thinking = _streamingThinkingBuffer;
    if (thinking != null) {
      _streamingThinking = thinking.toString();
    }
    final bash = _bashOutputBuffer;
    if (bash != null) {
      _bashOutput = bash.toString();
    }
  }
}
