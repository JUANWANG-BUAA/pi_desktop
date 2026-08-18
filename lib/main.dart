import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pi_desktop/pi_desktop.dart';

void main() {
  runApp(const PiDesktopApp());
}

class PiDesktopApp extends StatefulWidget {
  const PiDesktopApp({super.key, this.autoConnect = true});

  final bool autoConnect;

  @override
  State<PiDesktopApp> createState() => _PiDesktopAppState();
}

class _PiDesktopAppState extends State<PiDesktopApp> {
  late final PiDesktopConnection _connection;

  @override
  void initState() {
    super.initState();
    _connection = PiDesktopConnection();
    if (widget.autoConnect) {
      unawaited(_connection.connect());
    }
  }

  @override
  void dispose() {
    _connection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark(useMaterial3: true);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pi Desktop',
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFF17191C),
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF91A9B8),
              brightness: Brightness.dark,
            ).copyWith(
              surface: const Color(0xFF1D2024),
              surfaceContainer: const Color(0xFF20242A),
              outline: const Color(0xFF3A4148),
            ),
        dividerColor: const Color(0xFF343A40),
        textTheme: baseTheme.textTheme.apply(
          bodyColor: const Color(0xFFE1E5E8),
          displayColor: const Color(0xFFE1E5E8),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      home: DesktopShell(connection: _connection),
    );
  }
}

class DesktopShell extends StatefulWidget {
  const DesktopShell({required this.connection, super.key});

  final PiDesktopConnection connection;

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  late final StreamSubscription<PiJsonObject> _extensionUiSubscription;

  PiDesktopConnection get _connection => widget.connection;

  @override
  void initState() {
    super.initState();
    _extensionUiSubscription = _connection.extensionUiRequests.listen(
      _handleExtensionUiRequest,
    );
  }

  @override
  void dispose() {
    unawaited(_extensionUiSubscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _connection,
      builder: (context, child) => _ShellLayout(connection: _connection),
    );
  }

  Future<void> _handleExtensionUiRequest(PiJsonObject request) async {
    final method = request['method'];
    final requestId = request['id'];
    if (method == 'notify') {
      if (mounted) {
        final message = request['message'] as String? ?? '';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    if (requestId is! String || !mounted) {
      return;
    }

    switch (method) {
      case 'select':
        final options = request['options'] is List
            ? (request['options'] as List).whereType<String>().toList()
            : const <String>[];
        final value = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(request['title'] as String? ?? 'Select'),
            children: [
              for (final option in options)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(option),
                  child: Text(option),
                ),
            ],
          ),
        );
        await _respond(requestId, value: value, cancelled: value == null);
      case 'confirm':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(request['title'] as String? ?? 'Confirm'),
            content: Text(request['message'] as String? ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );
        await _respond(
          requestId,
          confirmed: confirmed,
          cancelled: confirmed == null,
        );
      case 'input':
      case 'editor':
        final controller = TextEditingController(
          text: request['prefill'] as String? ?? '',
        );
        final value = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(request['title'] as String? ?? 'Input'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: method == 'editor' ? 8 : 1,
              decoration: InputDecoration(
                hintText: request['placeholder'] as String?,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Submit'),
              ),
            ],
          ),
        );
        controller.dispose();
        await _respond(requestId, value: value, cancelled: value == null);
    }
  }

  Future<void> _respond(
    String requestId, {
    String? value,
    bool? confirmed,
    bool cancelled = false,
  }) async {
    try {
      await _connection.respondToExtensionUi(
        requestId,
        value: value,
        confirmed: confirmed,
        cancelled: cancelled,
      );
    } on Object {
      // The Pi process may exit while a dialog is open. Its lifecycle state
      // remains the source of truth for that failure.
    }
  }
}

class _ShellLayout extends StatelessWidget {
  const _ShellLayout({required this.connection});

  final PiDesktopConnection connection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ContextBar(connection: connection),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showInspector = constraints.maxWidth >= 980;
                  return Row(
                    children: [
                      SizedBox(
                        width: 260,
                        child: _ArchivePane(projection: connection.projection),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _TranscriptPane(
                          projection: connection.projection,
                        ),
                      ),
                      if (showInspector) ...[
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 280,
                          child: _InspectorPane(connection: connection),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            _PromptBar(connection: connection),
          ],
        ),
      ),
    );
  }
}

class _ContextBar extends StatelessWidget {
  const _ContextBar({required this.connection});

  final PiDesktopConnection connection;

  @override
  Widget build(BuildContext context) {
    final projection = connection.projection;
    final status = _statusData(context, connection.status);
    final model = _modelLabel(projection?.state);
    final title = connection.extensionTitle ?? 'Pi Desktop';
    final thinking = projection?.state?['thinkingLevel'] as String?;

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const _ContextValue(label: 'cwd', value: 'Pi provided'),
                  const SizedBox(width: 20),
                  _ContextValue(
                    label: 'session',
                    value: _sessionLabel(projection?.state),
                  ),
                  if (model != null) ...[
                    const SizedBox(width: 20),
                    _ContextValue(label: 'model', value: model),
                  ],
                  if (thinking != null) ...[
                    const SizedBox(width: 20),
                    _ContextValue(label: 'thinking', value: thinking),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (connection.status != PiConnectionStatus.connected &&
              connection.status != PiConnectionStatus.connecting)
            IconButton(
              tooltip: connection.status == PiConnectionStatus.crashed
                  ? 'Restart Pi RPC'
                  : 'Connect to Pi RPC',
              onPressed: () => unawaited(connection.restart()),
              icon: const Icon(Icons.refresh_outlined, size: 18),
            ),
          _StatusLabel(
            icon: status.icon,
            label: status.label,
            color: status.color,
          ),
        ],
      ),
    );
  }
}

class _ContextValue extends StatelessWidget {
  const _ContextValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodySmall,
        children: [
          TextSpan(
            text: '$label  ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _ArchivePane extends StatelessWidget {
  const _ArchivePane({required this.projection});

  final PiSessionProjection? projection;

  @override
  Widget build(BuildContext context) {
    final state = projection?.state;
    final sessionId = state?['sessionId'] as String?;
    final sessionName = state?['sessionName'] as String?;

    return _Pane(
      title: 'Session Archive',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            'PROJECT',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(_cwdLabel(state), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),
          Text(
            'CURRENT SESSION',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          if (sessionId == null)
            Text(
              'No Pi Session loaded',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            )
          else ...[
            Text(
              sessionName ?? sessionId,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${projection?.messages.length ?? 0} messages from Pi',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TranscriptPane extends StatelessWidget {
  const _TranscriptPane({required this.projection});

  final PiSessionProjection? projection;

  @override
  Widget build(BuildContext context) {
    final messages = projection?.messages ?? const <PiJsonObject>[];
    final toolEvents = projection?.toolEvents ?? const <PiJsonObject>[];
    final timelineEvents = projection?.timelineEvents ?? const <PiJsonObject>[];
    final streamingText = projection?.streamingText;
    final streamingThinking = projection?.streamingThinking;
    final hasContent =
        messages.isNotEmpty ||
        toolEvents.isNotEmpty ||
        timelineEvents.isNotEmpty ||
        streamingText != null ||
        streamingThinking != null;

    return _Pane(
      title: 'Transcript',
      child: !hasContent
          ? _EmptyTranscript(connected: projection != null)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
              itemCount:
                  timelineEvents.length +
                  toolEvents.length +
                  messages.length +
                  (streamingText == null && streamingThinking == null ? 0 : 1),
              separatorBuilder: (context, index) => const Divider(height: 28),
              itemBuilder: (context, index) {
                if (index < timelineEvents.length) {
                  return _TimelineDocument(event: timelineEvents[index]);
                }
                final afterTimeline = index - timelineEvents.length;
                if (afterTimeline < toolEvents.length) {
                  return _ToolEventDocument(event: toolEvents[afterTimeline]);
                }
                final messageIndex = afterTimeline - toolEvents.length;
                if (messageIndex < messages.length) {
                  return _MessageDocument.fromMessage(messages[messageIndex]);
                }
                return _MessageDocument(
                  roleLabel: 'assistant · streaming',
                  text: streamingText ?? '',
                  thinkingText: streamingThinking,
                  streamingText: true,
                );
              },
            ),
    );
  }
}

class _EmptyTranscript extends StatelessWidget {
  const _EmptyTranscript({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connected ? Icons.description_outlined : Icons.link_off_outlined,
              size: 34,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 18),
            Text(
              connected ? 'No Pi Session loaded' : 'Pi RPC is not connected',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              connected
                  ? 'The transcript will be restored from Pi through the official RPC connection.'
                  : 'Connect to the official Pi RPC process to restore a Session.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageDocument extends StatelessWidget {
  const _MessageDocument({
    required this.roleLabel,
    required this.text,
    this.thinkingText,
    this.streamingText = false,
  });

  factory _MessageDocument.fromMessage(PiJsonObject message) {
    final role = message['role'] as String? ?? 'message';
    final roleLabel = role == 'toolResult'
        ? 'tool result · ${message['toolName'] ?? 'unknown'}'
        : role;
    return _MessageDocument(
      roleLabel: roleLabel,
      text: _messageText(message),
      thinkingText: _thinkingText(message),
    );
  }

  final String roleLabel;
  final String text;
  final String? thinkingText;
  final bool streamingText;

  @override
  Widget build(BuildContext context) {
    final labelColor = streamingText
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final shownText = streamingText
        ? text
        : text.isEmpty
        ? '—'
        : text;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            roleLabel.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          if (shownText.isNotEmpty)
            SelectableText(
              shownText,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(height: 1.5),
            ),
          if (thinkingText != null && thinkingText!.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('Thinking'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    thinkingText!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ToolEventDocument extends StatelessWidget {
  const _ToolEventDocument({required this.event});

  final PiJsonObject event;

  @override
  Widget build(BuildContext context) {
    final toolName = event['toolName'] as String? ?? 'unknown';
    final type = event['type'] as String? ?? 'tool_execution';
    final isError = event['isError'] == true;
    final payload = event['result'] ?? event['partialResult'];
    final payloadText = _toolPayloadText(payload);
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$type · $toolName'.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          if (payloadText.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              payloadText,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: color, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineDocument extends StatelessWidget {
  const _TimelineDocument({required this.event});

  final PiJsonObject event;

  @override
  Widget build(BuildContext context) {
    final type = event['type'] as String? ?? 'Pi event';
    final detail =
        event['errorMessage'] ??
        event['finalError'] ??
        (event['result'] is Map ? (event['result'] as Map)['summary'] : null);
    final text = detail is String ? '$type: $detail' : type;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _InspectorPane extends StatefulWidget {
  const _InspectorPane({required this.connection});

  final PiDesktopConnection connection;

  @override
  State<_InspectorPane> createState() => _InspectorPaneState();
}

class _InspectorPaneState extends State<_InspectorPane> {
  String? _selectedEntryId;
  String? _actionError;

  PiDesktopConnection get _connection => widget.connection;

  @override
  Widget build(BuildContext context) {
    final projection = _connection.projection;
    final treeEntries = _flattenTree(projection?.tree?['tree']);
    final currentModel = _currentModel(projection?.state);
    final modelItems = projection?.availableModels ?? const <PiJsonObject>[];
    final modelValues = modelItems
        .where((model) => model['provider'] is String && model['id'] is String)
        .map((model) => '${model['provider']}/${model['id']}')
        .toSet();
    final selectedModel = modelValues.contains(currentModel)
        ? currentModel
        : null;
    final thinkingLevels = projection?.thinkingLevels ?? const <String>[];
    final currentThinking = projection?.state?['thinkingLevel'] as String?;
    final selectedThinking = thinkingLevels.contains(currentThinking)
        ? currentThinking
        : null;
    final commandSources = (projection?.commands ?? const <PiJsonObject>[])
        .map((command) => command['source'])
        .whereType<String>()
        .toSet();

    return _Pane(
      title: 'Inspector',
      child: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: [
          _InspectorSection(
            title: 'Stream',
            value: projection?.isStreaming == true ? 'active' : 'idle',
          ),
          _InspectorSection(
            title: 'Last Pi event',
            value: projection?.lastEventType ?? 'none',
          ),
          _InspectorSection(
            title: 'Messages',
            value: '${projection?.messages.length ?? 0}',
          ),
          if (_actionError != null)
            Text(
              _actionError!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          _InspectorSection(title: 'Model', value: ''),
          if (modelItems.isEmpty)
            const Text('Pi returned no available models.')
          else
            DropdownButton<String>(
              isExpanded: true,
              value: selectedModel,
              hint: const Text('Select model'),
              items: [
                for (final model in modelItems)
                  if (model['provider'] is String && model['id'] is String)
                    DropdownMenuItem<String>(
                      value: '${model['provider']}/${model['id']}',
                      child: Text(
                        '${model['provider']}/${model['id']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
              onChanged: _connection.isConnected
                  ? (value) {
                      if (value == null) return;
                      final separator = value.indexOf('/');
                      if (separator <= 0 || separator == value.length - 1) {
                        return;
                      }
                      unawaited(
                        _runAction(
                          () => _connection.setModel(
                            value.substring(0, separator),
                            value.substring(separator + 1),
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          const SizedBox(height: 10),
          _InspectorSection(title: 'Thinking level', value: ''),
          if (thinkingLevels.isEmpty)
            const Text('Pi returned no thinking levels.')
          else
            DropdownButton<String>(
              isExpanded: true,
              value: selectedThinking,
              hint: const Text('Select thinking level'),
              items: [
                for (final level in thinkingLevels)
                  DropdownMenuItem<String>(value: level, child: Text(level)),
              ],
              onChanged: _connection.isConnected
                  ? (level) {
                      if (level != null) {
                        unawaited(
                          _runAction(() => _connection.setThinkingLevel(level)),
                        );
                      }
                    }
                  : null,
            ),
          const SizedBox(height: 10),
          _InspectorSection(
            title: 'Queue',
            value:
                'steer ${projection?.steeringQueue.length ?? 0} · follow-up ${projection?.followUpQueue.length ?? 0}',
          ),
          if (projection?.commands.isNotEmpty == true) ...[
            _InspectorSection(title: 'Pi commands', value: ''),
            for (final command in projection!.commands.take(8))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('/${command['name'] ?? 'unknown'}'),
                subtitle: Text(
                  '${command['source'] ?? 'Pi'} · ${command['path'] ?? 'source unavailable'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          _InspectorSection(
            title: 'Pi resources',
            value: '${projection?.commands.length ?? 0} command(s)',
          ),
          Text(
            commandSources.isEmpty
                ? 'Pi returned no command resources.'
                : 'Sources: ${commandSources.join(', ')}. Paths are shown above.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Text(
            'Theme discovery remains Pi-owned; no private desktop scanner is used.',
          ),
          if (treeEntries.isNotEmpty) ...[
            _InspectorSection(title: 'Session tree', value: ''),
            for (final item in treeEntries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                selected: _selectedEntryId == item.id,
                title: Text(item.id),
                subtitle: Text(
                  '${item.role} · parent ${item.parentId ?? 'root'}${item.label == null ? '' : ' · ${item.label}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => setState(() => _selectedEntryId = item.id),
                trailing: IconButton(
                  tooltip: 'Fork from this Pi Entry',
                  onPressed: _connection.isConnected
                      ? () => unawaited(
                          _runAction(() => _connection.fork(item.id)),
                        )
                      : null,
                  icon: const Icon(Icons.call_split_outlined, size: 18),
                ),
              ),
          ],
          const SizedBox(height: 8),
          _InspectorSection(title: 'Actions', value: 'Pi commands'),
          Wrap(
            spacing: 2,
            children: [
              IconButton(
                tooltip: 'New Pi Session',
                onPressed: _connection.isConnected
                    ? () => unawaited(_runAction(_connection.newSession))
                    : null,
                icon: const Icon(Icons.note_add_outlined),
              ),
              IconButton(
                tooltip: 'Switch Pi Session',
                onPressed: _connection.isConnected
                    ? () => unawaited(_switchSession(context))
                    : null,
                icon: const Icon(Icons.folder_open_outlined),
              ),
              IconButton(
                tooltip: 'Clone Pi Session',
                onPressed: _connection.isConnected
                    ? () => unawaited(_runAction(_connection.clone))
                    : null,
                icon: const Icon(Icons.copy_outlined),
              ),
              IconButton(
                tooltip: 'Compact through Pi',
                onPressed: _connection.isConnected
                    ? () => unawaited(_runAction(() => _connection.compact()))
                    : null,
                icon: const Icon(Icons.compress_outlined),
              ),
              IconButton(
                tooltip: 'Export Pi Session',
                onPressed: _connection.isConnected
                    ? () =>
                          unawaited(_runAction(() => _connection.exportHtml()))
                    : null,
                icon: const Icon(Icons.ios_share_outlined),
              ),
            ],
          ),
          if (projection?.sessionStats != null)
            _InspectorSection(
              title: 'Usage',
              value: _usageLabel(projection!.sessionStats!),
            ),
        ],
      ),
    );
  }

  Future<void> _switchSession(BuildContext context) async {
    final controller = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch Pi Session'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Session JSONL path'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (path == null || path.trim().isEmpty) {
      return;
    }
    await _runAction(() => _connection.switchSession(path.trim()));
  }

  Future<void> _runAction(Future<PiRpcResponse> Function() action) async {
    try {
      final response = await action();
      if (!response.success && mounted) {
        setState(() => _actionError = response.error ?? 'Pi command failed');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _actionError = error.toString());
      }
    }
  }
}

class _TreeItem {
  const _TreeItem({
    required this.id,
    required this.parentId,
    required this.role,
    required this.label,
  });

  final String id;
  final String? parentId;
  final String role;
  final String? label;
}

List<_TreeItem> _flattenTree(Object? value) {
  if (value is! List) {
    return const <_TreeItem>[];
  }

  final result = <_TreeItem>[];
  void visit(Object? rawNode) {
    if (rawNode is! Map) {
      return;
    }
    final node = Map<String, dynamic>.from(rawNode);
    final rawEntry = node['entry'];
    if (rawEntry is Map) {
      final entry = Map<String, dynamic>.from(rawEntry);
      final id = entry['id'];
      if (id is String) {
        final message = entry['message'];
        result.add(
          _TreeItem(
            id: id,
            parentId: entry['parentId'] as String?,
            role: message is Map && message['role'] is String
                ? message['role'] as String
                : entry['type'] as String? ?? 'entry',
            label: node['label'] as String?,
          ),
        );
      }
    }
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        visit(child);
      }
    }
  }

  for (final node in value) {
    visit(node);
  }
  return result;
}

String? _currentModel(PiJsonObject? state) {
  final model = state?['model'];
  if (model is! Map || model['provider'] is! String || model['id'] is! String) {
    return null;
  }
  return '${model['provider']}/${model['id']}';
}

String _usageLabel(PiJsonObject stats) {
  final contextUsage = stats['contextUsage'];
  if (contextUsage is Map && contextUsage['percent'] is num) {
    return '${contextUsage['percent']}% context';
  }
  final tokens = stats['tokens'];
  if (tokens is Map && tokens['total'] is num) {
    return '${tokens['total']} tokens';
  }
  return 'Pi usage available';
}

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(18), child: child),
          ),
        ],
      ),
    );
  }
}

class _PromptBar extends StatefulWidget {
  const _PromptBar({required this.connection});

  final PiDesktopConnection connection;

  @override
  State<_PromptBar> createState() => _PromptBarState();
}

class _PromptBarState extends State<_PromptBar> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  String? _error;
  String? _appliedExtensionText;

  PiDesktopConnection get _connection => widget.connection;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _connection.isConnected;
    final streaming = _connection.isStreaming;
    final widgetLines = _connection.extensionWidgets.values
        .expand((lines) => lines)
        .toList(growable: false);
    final statusText = _connection.extensionStatuses.values.join(' · ');
    final extensionText = _connection.extensionEditorText;
    final commandSuggestions = _commandSuggestions(
      _textController.text,
      _connection.projection?.commands ?? const <PiJsonObject>[],
    );
    if (extensionText != null && extensionText != _appliedExtensionText) {
      _appliedExtensionText = extensionText;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _textController.text = extensionText;
        }
      });
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (statusText.isNotEmpty)
            Text(
              statusText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          if (widgetLines.isNotEmpty)
            for (final line in widgetLines)
              Text(
                line,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          if (_error != null) ...[
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  enabled: enabled,
                  onChanged: (_) => setState(() {}),
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: enabled
                        ? 'Write a prompt for Pi'
                        : 'Prompt will be sent through Pi RPC',
                    prefixIcon: const Icon(Icons.edit_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (streaming) ...[
                TextButton(
                  onPressed: enabled ? () => _submit(_connection.steer) : null,
                  child: const Text('Steer'),
                ),
                TextButton(
                  onPressed: enabled
                      ? () => _submit(_connection.followUp)
                      : null,
                  child: const Text('Follow up'),
                ),
                IconButton(
                  tooltip: 'Abort Pi',
                  onPressed: enabled ? _abort : null,
                  icon: const Icon(Icons.stop_outlined),
                ),
              ] else
                IconButton(
                  tooltip: 'Send prompt through Pi',
                  onPressed: enabled ? () => _submit(_connection.prompt) : null,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
            ],
          ),
          if (commandSuggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final command in commandSuggestions)
                    ActionChip(
                      label: Text('/${command['name']}'),
                      onPressed: () {
                        _textController.text = '/${command['name']} ';
                        _focusNode.requestFocus();
                        setState(() {});
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submit(
    Future<PiRpcResponse> Function(String message) send,
  ) async {
    final message = _textController.text.trim();
    if (message.isEmpty) {
      return;
    }

    _textController.clear();
    try {
      await send(message);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<void> _abort() async {
    try {
      await _connection.abort();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }
}

List<PiJsonObject> _commandSuggestions(
  String text,
  List<PiJsonObject> commands,
) {
  if (!text.startsWith('/')) {
    return const <PiJsonObject>[];
  }
  final query = text.substring(1).split(' ').first.toLowerCase();
  return commands
      .where((command) {
        final name = command['name'];
        return name is String && name.toLowerCase().startsWith(query);
      })
      .take(6)
      .toList(growable: false);
}

class _StatusData {
  const _StatusData(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;
}

_StatusData _statusData(BuildContext context, PiConnectionStatus status) {
  final colors = Theme.of(context).colorScheme;
  return switch (status) {
    PiConnectionStatus.disconnected => _StatusData(
      Icons.link_off_outlined,
      'Pi RPC disconnected',
      colors.onSurfaceVariant,
    ),
    PiConnectionStatus.connecting => _StatusData(
      Icons.sync_outlined,
      'Connecting to Pi RPC',
      colors.primary,
    ),
    PiConnectionStatus.connected => _StatusData(
      Icons.link_outlined,
      'Pi RPC connected',
      colors.primary,
    ),
    PiConnectionStatus.stopping => _StatusData(
      Icons.hourglass_bottom_outlined,
      'Stopping Pi RPC',
      colors.onSurfaceVariant,
    ),
    PiConnectionStatus.crashed => _StatusData(
      Icons.error_outline,
      'Pi RPC exited',
      colors.error,
    ),
  };
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

String _sessionLabel(PiJsonObject? state) {
  final name = state?['sessionName'] as String?;
  final id = state?['sessionId'] as String?;
  return name ?? id ?? 'not loaded';
}

String _cwdLabel(PiJsonObject? state) {
  final sessionFile = state?['sessionFile'] as String?;
  if (sessionFile == null || sessionFile.isEmpty) {
    return 'Pi working directory';
  }
  return sessionFile;
}

String? _modelLabel(PiJsonObject? state) {
  final model = state?['model'];
  if (model is! Map) {
    return null;
  }
  final provider = model['provider'];
  final id = model['id'];
  if (provider is String && id is String) {
    return '$provider/$id';
  }
  return id as String?;
}

String _messageText(PiJsonObject message) {
  final content = message['content'];
  if (content is String) {
    return content;
  }
  if (content is! List) {
    return '';
  }

  final parts = <String>[];
  for (final block in content.whereType<Map>()) {
    final type = block['type'];
    switch (type) {
      case 'text':
        if (block['text'] is String) {
          parts.add(block['text'] as String);
        }
      case 'image':
        parts.add('[image content from Pi]');
      case 'toolCall':
        final name = block['name'];
        final arguments = block['arguments'];
        final argumentText = arguments == null
            ? ''
            : '${String.fromCharCode(10)}${jsonEncode(arguments)}';
        parts.add(
          'Tool call: ${name is String ? name : 'unknown'}$argumentText',
        );
    }
  }

  final details = message['details'];
  if (details is Map && details['diff'] is String) {
    parts.add('Diff:\n${details['diff']}');
  }
  return parts.join('\n\n');
}

String? _thinkingText(PiJsonObject message) {
  final content = message['content'];
  if (content is! List) {
    return null;
  }
  final parts = <String>[];
  for (final block in content.whereType<Map>()) {
    if (block['type'] == 'thinking' && block['thinking'] is String) {
      parts.add(block['thinking'] as String);
    }
  }
  return parts.isEmpty ? null : parts.join('\n');
}

String _toolPayloadText(Object? payload) {
  if (payload is! Map) {
    return payload is String ? payload : '';
  }
  final content = payload['content'];
  if (content is List) {
    final text = content
        .whereType<Map>()
        .where((item) => item['type'] == 'text' && item['text'] is String)
        .map((item) => item['text'] as String)
        .join('\n');
    if (text.isNotEmpty) {
      return text;
    }
  }
  return jsonEncode(payload);
}
