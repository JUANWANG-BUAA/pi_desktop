import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../session/pi_desktop_connection.dart';
import '../session/pi_session_projection.dart';
import 'content_format.dart' as format;
import 'listenables.dart';
import 'markdown_document.dart';
import 'pi_tokens.dart';
import 'widgets.dart';

class TranscriptPane extends StatefulWidget {
  const TranscriptPane({
    required this.connection,
    required this.projection,
    super.key,
  });

  final PiDesktopConnection connection;
  final PiSessionProjection? projection;

  @override
  State<TranscriptPane> createState() => _TranscriptPaneState();
}

class _TranscriptPaneState extends State<TranscriptPane> {
  final _controller = ScrollController();
  var _stickToBottom = true;
  var _showIntermediate = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant TranscriptPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleStick();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projection = widget.projection;
    final documents = projection?.documents ?? const <PiTranscriptItem>[];
    final committed = documents
        .where(
          (item) =>
              item.kind == PiTranscriptKind.message ||
              item.kind == PiTranscriptKind.timeline,
        )
        .toList(growable: false);
    final rows = _buildTranscriptRows(
      _showIntermediate
          ? committed
          : committed
                .where((item) => !isIntermediateTranscriptItem(item))
                .toList(),
    );
    final hasIntermediate = committed.any(isIntermediateTranscriptItem);

    if (committed.isEmpty && projection == null) {
      return EmptyTranscript(
        connected: false,
        onConnect: () => unawaited(widget.connection.restart()),
      );
    }

    if (committed.isEmpty) {
      return Column(
        children: [
          Expanded(child: EmptyTranscript(connected: true, onConnect: null)),
          if (projection != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
              child: _LiveLane(projection: projection),
            ),
        ],
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          controller: _controller,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final row = rows[index];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: RepaintBoundary(
                          child: row.build(key: ValueKey(row.keyFor(index))),
                        ),
                      ),
                    ),
                  );
                }, childCount: rows.length),
              ),
            ),
            if (projection != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: _LiveLane(projection: projection),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Positioned(
          top: 8,
          right: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasIntermediate)
                IconButton(
                  tooltip: _showIntermediate
                      ? 'Hide intermediate Pi activity'
                      : 'Show intermediate Pi activity',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _showIntermediate = !_showIntermediate),
                  icon: Icon(
                    _showIntermediate
                        ? Icons.unfold_less_rounded
                        : Icons.unfold_more_rounded,
                    size: 15,
                  ),
                ),
              IconButton(
                tooltip: 'Copy transcript',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final buffer = StringBuffer();
                  for (final item in documents) {
                    buffer.writeln(_plain(item));
                    buffer.writeln();
                  }
                  if (projection?.streamingText != null) {
                    buffer.writeln(projection!.streamingText);
                  }
                  copyText(buffer.toString());
                },
                icon: const Icon(Icons.copy_outlined, size: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onScroll() {
    if (!_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    _stickToBottom = position.pixels >= position.maxScrollExtent - 64;
  }

  void _scheduleStick() {
    if (!_stickToBottom) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) {
        return;
      }
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  List<_TranscriptRow> _buildTranscriptRows(List<PiTranscriptItem> items) {
    final rows = <_TranscriptRow>[];
    final activity = <PiTranscriptItem>[];

    void flushActivity() {
      if (activity.isEmpty) return;
      // A single lifecycle event can still contain substantial tool output.
      // Keep every intermediate run in the same default-collapsed surface so
      // long Pi sessions do not grow just because an activity batch is short.
      rows.add(_ActivityTranscriptRow(List.unmodifiable(activity)));
      activity.clear();
    }

    for (final item in items) {
      if (isIntermediateTranscriptItem(item)) {
        activity.add(item);
      } else {
        flushActivity();
        rows.add(_SingleTranscriptRow(item));
      }
    }
    flushActivity();
    return rows;
  }

  String _plain(PiTranscriptItem item) {
    switch (item.kind) {
      case PiTranscriptKind.message:
        return format.messageText(item.data!);
      case PiTranscriptKind.liveTool:
        return format.toolPayloadText(
          item.data!['result'] ?? item.data!['partialResult'],
        );
      case PiTranscriptKind.timeline:
        return item.data!['type'] as String? ?? 'event';
      case PiTranscriptKind.streaming:
        return item.streamingText ?? '';
    }
  }
}

/// Returns whether a persisted Pi item is execution trace rather than a
/// conversational turn. The full Pi-owned payload remains available in the
/// expandable cluster; this only prevents trace-only messages from consuming
/// a full transcript row each.
bool isIntermediateTranscriptItem(PiTranscriptItem item) {
  if (item.kind == PiTranscriptKind.timeline) return true;
  if (item.kind != PiTranscriptKind.message) return false;
  final message = item.data;
  if (message == null) return false;
  if (message['role'] == 'toolResult') return true;
  // Pi emits assistant turns containing only thinking and/or native tool calls
  // while it works. They are essential trace data, but not a reply to read.
  return message['role'] == 'assistant' &&
      format.visibleText(message).trim().isEmpty;
}

sealed class _TranscriptRow {
  const _TranscriptRow();

  String keyFor(int index);
  Widget build({required Key key});
}

class _SingleTranscriptRow extends _TranscriptRow {
  const _SingleTranscriptRow(this.item);

  final PiTranscriptItem item;

  @override
  String keyFor(int index) {
    final data = item.data;
    return '$index-${data?['id'] ?? data?['toolCallId'] ?? data?['type']}';
  }

  @override
  Widget build({required Key key}) => TranscriptDocument(key: key, item: item);
}

class _ActivityTranscriptRow extends _TranscriptRow {
  const _ActivityTranscriptRow(this.items);

  final List<PiTranscriptItem> items;

  @override
  String keyFor(int index) {
    final first = items.first.data;
    final last = items.last.data;
    return '$index-activity-${first?['id'] ?? first?['toolCallId'] ?? first?['type']}-${last?['id'] ?? last?['toolCallId'] ?? last?['type']}-${items.length}';
  }

  @override
  Widget build({required Key key}) => _ActivityCluster(key: key, items: items);
}

class _ActivityCluster extends StatelessWidget {
  const _ActivityCluster({required this.items, super.key});

  final List<PiTranscriptItem> items;

  @override
  Widget build(BuildContext context) {
    final toolResults = items
        .where((item) => item.data?['role'] == 'toolResult')
        .length;
    final events = items.length - toolResults;
    final label = switch ((toolResults, events)) {
      (0, final count) => 'Pi activity · $count events',
      (final count, 0) =>
        'Pi activity · $count tool ${count == 1 ? 'result' : 'results'}',
      _ => 'Pi activity · ${items.length} steps · $toolResults tools',
    };
    return FoldBlock(
      title: label,
      accent: PiTokens.of(context).textFaint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < items.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == items.length - 1 ? 0 : 8,
              ),
              child: TranscriptDocument(item: items[index]),
            ),
        ],
      ),
    );
  }
}

class _LiveLane extends StatelessWidget {
  const _LiveLane({required this.projection});

  final PiSessionProjection projection;

  @override
  Widget build(BuildContext context) {
    return ProjectionListener(
      projection: projection,
      builder: (context, projection) {
        final hasStreaming =
            projection.isStreaming &&
            (projection.streamingText != null ||
                projection.streamingThinking != null);
        final knownToolIds = <String>{};
        for (final message in projection.messages) {
          final toolCallId = message['toolCallId'];
          if (toolCallId is String) {
            knownToolIds.add(toolCallId);
          }
          final content = message['content'];
          if (content is List) {
            for (final block in content.whereType<Map>()) {
              final id = block['id'];
              if (block['type'] == 'toolCall' && id is String) {
                knownToolIds.add(id);
              }
            }
          }
        }
        final liveTools = projection.toolEvents
            .where((event) {
              final id = event['toolCallId'];
              return id is! String || !knownToolIds.contains(id);
            })
            .toList(growable: false);
        if (!hasStreaming && liveTools.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final event in liveTools)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ToolEventDocument(event: event),
              ),
            if (hasStreaming)
              MessageDocument(
                roleLabel: 'assistant',
                text: projection.streamingText ?? '',
                thinkingText: projection.streamingThinking,
                streaming: true,
              ),
          ],
        );
      },
    );
  }
}

class EmptyTranscript extends StatelessWidget {
  const EmptyTranscript({required this.connected, super.key, this.onConnect});

  final bool connected;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 22, color: tokens.accent),
              const SizedBox(height: 16),
              Text(
                connected
                    ? 'What should Pi work on?'
                    : 'Connect Pi RPC to start',
                style: tokens.display.copyWith(fontSize: 26),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                connected
                    ? 'The transcript is restored from Pi. Prompt, steer and follow-up stay official RPC commands.'
                    : 'Pi Desktop is a thin client. Connect to the official Pi RPC process to restore a Session.',
                style: tokens.control.copyWith(
                  color: tokens.textSoft,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (!connected && onConnect != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onConnect,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Connect to Pi RPC'),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'No Pi Session loaded',
                style: tokens.control.copyWith(color: tokens.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TranscriptDocument extends StatelessWidget {
  const TranscriptDocument({required this.item, super.key});

  final PiTranscriptItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.kind) {
      case PiTranscriptKind.message:
        return MessageDocument.fromMessage(item.data!);
      case PiTranscriptKind.liveTool:
        return ToolEventDocument(event: item.data!);
      case PiTranscriptKind.timeline:
        return TimelineDocument(event: item.data!);
      case PiTranscriptKind.streaming:
        return MessageDocument(
          roleLabel: 'assistant',
          text: item.streamingText ?? '',
          thinkingText: item.streamingThinking,
          streaming: true,
        );
    }
  }
}

class MessageDocument extends StatelessWidget {
  const MessageDocument({
    required this.roleLabel,
    required this.text,
    super.key,
    this.thinkingText,
    this.streaming = false,
    this.isError = false,
    this.toolName,
    this.blocks = const <Map<String, dynamic>>[],
    this.payloadText,
  });

  factory MessageDocument.fromMessage(PiJsonObject message) {
    final role = message['role'] as String? ?? 'message';
    return MessageDocument(
      roleLabel: role,
      text: format.visibleText(message),
      thinkingText: format.thinkingText(message),
      isError: message['isError'] == true,
      toolName: message['toolName'] as String?,
      blocks: format.contentBlocks(message).toList(growable: false),
      payloadText: role == 'toolResult'
          ? format.toolPayloadText(message)
          : null,
    );
  }

  final String roleLabel;
  final String text;
  final String? thinkingText;
  final bool streaming;
  final bool isError;
  final String? toolName;
  final List<Map<String, dynamic>> blocks;
  final String? payloadText;

  @override
  Widget build(BuildContext context) {
    if (roleLabel == 'user') {
      return _UserBubble(text: text, blocks: blocks);
    }
    if (roleLabel == 'toolResult') {
      return _CollapsedPayload(
        title: toolName ?? 'Tool result',
        text: payloadText == null || payloadText!.isEmpty ? text : payloadText!,
        isError: isError,
      );
    }
    return _AssistantTurn(
      text: text,
      thinkingText: thinkingText,
      streaming: streaming,
      blocks: blocks,
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text, required this.blocks});

  final String text;
  final List<Map<String, dynamic>> blocks;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final imageBlocks = blocks
        .where((block) => block['type'] == 'image')
        .toList(growable: false);
    final images = imageBlocks
        .map(_messageImageBytes)
        .whereType<Uint8List>()
        .toList(growable: false);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: tokens.panelSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (text.isNotEmpty)
                SelectableText(
                  text,
                  textAlign: TextAlign.left,
                  style: tokens.reading.copyWith(fontSize: 15, height: 1.45),
                ),
              if (images.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: text.isEmpty ? 0 : 8),
                  child: _MessageImageGrid(images: images),
                )
              else if (imageBlocks.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: text.isEmpty ? 0 : 8),
                  child: Text(
                    imageBlocks.length == 1
                        ? 'Image attachment'
                        : '${imageBlocks.length} image attachments',
                    style: tokens.control.copyWith(
                      color: tokens.textFaint,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pi persists attachment payloads in the message it owns. The desktop only
/// decodes them for a bounded visual preview and never writes a copy elsewhere.
Uint8List? _messageImageBytes(Map<String, dynamic> block) {
  final data = block['data'];
  if (data is! String || data.isEmpty) {
    return null;
  }
  final comma = data.indexOf(',');
  final encoded = data.startsWith('data:') && comma >= 0
      ? data.substring(comma + 1)
      : data;
  try {
    return base64Decode(encoded);
  } on FormatException {
    return null;
  }
}

class _MessageImageGrid extends StatelessWidget {
  const _MessageImageGrid({required this.images});

  final List<Uint8List> images;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final single = images.length == 1;
    return Semantics(
      label: images.length == 1
          ? 'Attached image preview'
          : '${images.length} attached image previews',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final image in images)
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: single ? 300 : 142,
                  height: single ? 210 : 106,
                  child: Image.memory(
                    image,
                    fit: BoxFit.cover,
                    cacheWidth: single ? 600 : 284,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: tokens.bg,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: tokens.textFaint,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssistantTurn extends StatelessWidget {
  const _AssistantTurn({
    required this.text,
    required this.thinkingText,
    required this.streaming,
    required this.blocks,
  });

  final String text;
  final String? thinkingText;
  final bool streaming;
  final List<Map<String, dynamic>> blocks;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final children = <Widget>[];
    if (blocks.isEmpty) {
      if (thinkingText != null && thinkingText!.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FoldBlock(
              title: 'Thinking',
              child: SelectableText(
                thinkingText!,
                style: tokens.reading.copyWith(
                  color: tokens.textSoft,
                  fontSize: tokens.readingSize - 0.5,
                ),
              ),
            ),
          ),
        );
      }
      if (text.isNotEmpty) {
        children.add(
          streaming
              ? SelectableText(text, style: tokens.reading)
              : MarkdownDocument(text: text),
        );
      }
    } else {
      for (final block in blocks) {
        children.add(_blockWidget(tokens, block));
      }
    }
    if (streaming) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: const _StreamingMark(),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _blockWidget(PiTokens tokens, Map<String, dynamic> block) {
    switch (block['type']) {
      case 'thinking':
        final thinking = block['thinking'] as String? ?? '';
        if (thinking.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FoldBlock(
            title: 'Thinking',
            child: SelectableText(
              thinking,
              style: tokens.reading.copyWith(
                color: tokens.textSoft,
                fontSize: tokens.readingSize - 0.5,
              ),
            ),
          ),
        );
      case 'toolCall':
        final name = block['name'] as String? ?? 'Tool call';
        final arguments = block['arguments'];
        final argumentText = arguments == null
            ? ''
            : format.toolPayloadText(arguments);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FoldBlock(
            title: name,
            child: argumentText.isEmpty
                ? const SizedBox.shrink()
                : CodeSurface(text: argumentText),
          ),
        );
      case 'image':
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Image',
            style: tokens.control.copyWith(color: tokens.textFaint),
          ),
        );
      case 'text':
        final body = block['text'] as String? ?? '';
        if (body.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: streaming
              ? SelectableText(body, style: tokens.reading)
              : MarkdownDocument(text: body),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StreamingMark extends StatefulWidget {
  const _StreamingMark();

  @override
  State<_StreamingMark> createState() => _StreamingMarkState();
}

class _StreamingMarkState extends State<_StreamingMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    if (MediaQuery.disableAnimationsOf(context)) {
      return Icon(Icons.auto_awesome, size: 14, color: tokens.accent);
    }
    return RepaintBoundary(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.38, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Icon(Icons.auto_awesome, size: 14, color: tokens.accent),
      ),
    );
  }
}

class _CollapsedPayload extends StatelessWidget {
  const _CollapsedPayload({
    required this.title,
    required this.text,
    required this.isError,
  });

  final String title;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: FoldBlock(
        title: title,
        accent: isError ? tokens.signalDanger : tokens.textFaint,
        child: text.isEmpty
            ? const SizedBox.shrink()
            : CodeSurface(
                text: text,
                color: isError ? tokens.signalDanger : tokens.text,
              ),
      ),
    );
  }
}

class ToolEventDocument extends StatelessWidget {
  const ToolEventDocument({required this.event, super.key});

  final PiJsonObject event;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final toolName = event['toolName'] as String? ?? 'unknown';
    final type = event['type'] as String? ?? 'tool_execution';
    final isError = event['isError'] == true;
    final payload = event['result'] ?? event['partialResult'];
    final payloadText = format.toolPayloadText(payload);
    final args = event['args'];
    final argsText = args == null ? '' : format.toolPayloadText(args);
    final truncated = format.truncationLabel(payload);
    final color = isError ? tokens.signalDanger : tokens.textSoft;

    return FoldBlock(
      title: '$toolName · $type',
      accent: isError ? tokens.signalDanger : tokens.textFaint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (argsText.isNotEmpty) ...[
            CodeSurface(text: argsText),
            const SizedBox(height: 8),
          ],
          if (payloadText.isNotEmpty)
            CodeSurface(text: payloadText, color: color),
          if (truncated.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Truncation: $truncated',
                style: tokens.evidence.copyWith(color: tokens.signalWarn),
              ),
            ),
        ],
      ),
    );
  }
}

class TimelineDocument extends StatelessWidget {
  const TimelineDocument({required this.event, super.key});

  final PiJsonObject event;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final type = event['type'] as String? ?? 'Pi event';
    final detail =
        event['errorMessage'] ??
        event['error'] ??
        event['finalError'] ??
        event['reason'] ??
        (event['result'] is Map ? (event['result'] as Map)['summary'] : null);
    final text = detail is String && detail.isNotEmpty
        ? '$type · $detail'
        : type;

    return Text(
      text,
      style: tokens.control.copyWith(color: tokens.textFaint, fontSize: 12.5),
    );
  }
}
