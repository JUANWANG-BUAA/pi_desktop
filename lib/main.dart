import 'dart:async';

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

class DesktopShell extends StatelessWidget {
  const DesktopShell({required this.connection, super.key});

  final PiDesktopConnection connection;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: connection,
      builder: (context, child) => _ShellLayout(connection: connection),
    );
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
            'Pi Desktop',
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
    final streamingText = projection?.streamingText;

    return _Pane(
      title: 'Transcript',
      child: messages.isEmpty && streamingText == null
          ? _EmptyTranscript(connected: projection != null)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
              itemCount: messages.length + (streamingText == null ? 0 : 1),
              separatorBuilder: (context, index) => const Divider(height: 28),
              itemBuilder: (context, index) {
                if (index == messages.length) {
                  return const _MessageDocument(
                    roleLabel: 'assistant · streaming',
                    text: '',
                    streamingText: true,
                  );
                }
                return _MessageDocument.fromMessage(messages[index]);
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
    this.streamingText = false,
  });

  factory _MessageDocument.fromMessage(PiJsonObject message) {
    final role = message['role'] as String? ?? 'message';
    return _MessageDocument(roleLabel: role, text: _messageText(message));
  }

  final String roleLabel;
  final String text;
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
          SelectableText(
            shownText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _InspectorPane extends StatelessWidget {
  const _InspectorPane({required this.connection});

  final PiDesktopConnection connection;

  @override
  Widget build(BuildContext context) {
    final projection = connection.projection;
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
          _InspectorSection(
            title: 'Branch / Tool / Usage',
            value: 'Available after Pi state is loaded',
          ),
        ],
      ),
    );
  }
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
  String? _error;

  PiDesktopConnection get _connection => widget.connection;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _connection.isConnected;
    final streaming = _connection.isStreaming;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  enabled: enabled,
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
      case 'toolCall':
        final name = block['name'];
        parts.add('Tool call: ${name is String ? name : 'unknown'}');
    }
  }
  return parts.join('\n\n');
}
