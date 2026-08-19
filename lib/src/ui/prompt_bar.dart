import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../rpc/pi_rpc_client.dart';
import '../session/pi_baseline.dart';
import '../session/pi_desktop_connection.dart';
import '../session/pi_session_projection.dart';
import 'content_format.dart';
import 'pi_tokens.dart';
import 'ui_preferences.dart';
import 'widgets.dart';
import 'workspace_io.dart';

class PromptBar extends StatefulWidget {
  const PromptBar({
    required this.connection,
    required this.preferences,
    required this.focusNode,
    super.key,
    this.landing = false,
    this.draftController,
  });

  final PiDesktopConnection connection;
  final UiPreferences preferences;
  final FocusNode focusNode;
  final bool landing;

  /// Composer draft owned by the shell so the text survives landing/session
  /// layout swaps. When null the bar keeps a private controller.
  final TextEditingController? draftController;

  @override
  State<PromptBar> createState() => PromptBarState();
}

class PromptBarState extends State<PromptBar> {
  TextEditingController? _localController;
  final _images = <_DraftImage>[];
  String? _error;
  String? _appliedExtensionText;

  PiDesktopConnection get _connection => widget.connection;

  TextEditingController get _textController =>
      widget.draftController ?? (_localController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    widget.focusNode.onKeyEvent = _onKeyEvent;
    widget.connection.addListener(_applyExtensionEditorText);
  }

  @override
  void didUpdateWidget(covariant PromptBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.onKeyEvent = null;
      widget.focusNode.onKeyEvent = _onKeyEvent;
    }
    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_applyExtensionEditorText);
      widget.connection.addListener(_applyExtensionEditorText);
    }
  }

  @override
  void dispose() {
    widget.focusNode.onKeyEvent = null;
    widget.connection.removeListener(_applyExtensionEditorText);
    _localController?.dispose();
    super.dispose();
  }

  /// Applies Pi Extension `set_editor_text` from the connection change
  /// notification instead of scheduling side effects during build.
  void _applyExtensionEditorText() {
    final extensionText = _connection.extensionEditorText;
    if (extensionText == null || extensionText == _appliedExtensionText) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _appliedExtensionText = extensionText;
      _textController.value = TextEditingValue(
        text: extensionText,
        selection: TextSelection.collapsed(offset: extensionText.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final enabled = _connection.isConnected;
    final streaming = _connection.isStreaming;
    final projection = _connection.projection;
    final widgetLines = _connection.extensionWidgets.values
        .expand((lines) => lines)
        .toList(growable: false);
    final statusText = _connection.extensionStatuses.values.join(' · ');
    final commandSuggestions = commandSuggestionsFor(
      _textController.text,
      projection?.commands ?? const <PiJsonObject>[],
    );
    final current = currentModel(projection?.state);
    final modelItems = projection?.availableModels ?? const <PiJsonObject>[];
    final modelValues = <String>[
      for (final model in modelItems)
        if (model['provider'] is String && model['id'] is String)
          '${model['provider']}/${model['id']}',
    ];
    final selectedModel = modelValues.contains(current) ? current : null;
    final thinkingLevels = projection?.thinkingLevels ?? const <String>[];
    final currentThinking = projection?.state?['thinkingLevel'] as String?;
    final selectedThinking = thinkingLevels.contains(currentThinking)
        ? currentThinking
        : null;
    final project = projectLabel(
      _connection.workingDirectory,
      projection?.state,
    );
    final steering = projection?.steeringQueue.length ?? 0;
    final followUp = projection?.followUpQueue.length ?? 0;
    final contextUsage = projection?.sessionStats?['contextUsage'];
    final contextPercent = contextUsage is Map
        ? contextUsage['percent'] as num?
        : null;

    final landing = widget.landing;
    final hint = enabled
        ? (landing ? 'How can I help you today?' : 'Type / for commands')
        : 'Prompt will be sent through Pi RPC';

    return Padding(
      padding: landing
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(0, 0, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!landing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ContextChip(
                    icon: Icons.dns_outlined,
                    label: enabled ? 'Local' : 'Offline',
                  ),
                  ContextChip(
                    icon: Icons.folder_outlined,
                    label: project,
                    onTap: () => unawaited(_chooseWorkspace()),
                  ),
                  if (currentThinking != null)
                    ContextChip(
                      icon: Icons.psychology_outlined,
                      label: currentThinking,
                    ),
                  if (steering + followUp > 0)
                    ContextChip(label: 'queue $steering / $followUp'),
                  if (contextPercent != null)
                    ContextChip(
                      icon: contextPercent >= 80
                          ? Icons.warning_amber_outlined
                          : Icons.pie_chart_outline,
                      label: 'context ${contextPercent.round()}%',
                    ),
                ],
              ),
            ),
          if (statusText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                statusText,
                style: tokens.control.copyWith(color: tokens.textSoft),
              ),
            ),
          if (widgetLines.isNotEmpty)
            for (final line in widgetLines)
              Text(
                line,
                style: tokens.evidence.copyWith(
                  color: tokens.textSoft,
                  fontSize: 11.5,
                ),
              ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: tokens.control.copyWith(color: tokens.signalDanger),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: tokens.panelSoft,
              borderRadius: BorderRadius.circular(tokens.composerRadius),
              border: Border.all(color: tokens.line),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_images.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < _images.length; i++)
                          _ImageAttachmentCard(
                            image: _images[i],
                            onRemove: () => setState(() => _images.removeAt(i)),
                          ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _textController,
                  focusNode: widget.focusNode,
                  enabled: enabled,
                  onChanged: (_) => setState(() {}),
                  minLines: landing ? 3 : 2,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: tokens.reading.copyWith(height: 1.45),
                  decoration: InputDecoration(
                    filled: false,
                    hintText: hint,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                  ),
                ),
                Row(
                  children: [
                    _AttachMenu(
                      tokens: tokens,
                      onImages: () => unawaited(_attachImages()),
                      onFilesUnavailable: () => setState(
                        () => _error =
                            'Pi $piBaselineVersion RPC has no file-attachment command. Images use official ImageContent. Other files wait on the upstream `files` field — see docs/rpc-upstream.md.',
                      ),
                      onWorkspace: () => unawaited(_chooseWorkspace()),
                    ),
                    if (modelValues.isNotEmpty) ...[
                      PiSelect<String>(
                        compact: true,
                        value: selectedModel,
                        hint: 'Model',
                        items: modelValues,
                        itemLabel: modelShortLabel,
                        onChanged: enabled
                            ? (value) {
                                if (value == null) {
                                  return;
                                }
                                final separator = value.indexOf('/');
                                if (separator <= 0) {
                                  return;
                                }
                                unawaited(
                                  _connection.setModel(
                                    value.substring(0, separator),
                                    value.substring(separator + 1),
                                  ),
                                );
                              }
                            : null,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (thinkingLevels.isNotEmpty)
                      PiSelect<String>(
                        compact: true,
                        value: selectedThinking,
                        hint: 'Thinking',
                        items: thinkingLevels,
                        onChanged: enabled
                            ? (level) {
                                if (level != null) {
                                  unawaited(
                                    _connection.setThinkingLevel(level),
                                  );
                                }
                              }
                            : null,
                      ),
                    const Spacer(),
                    if (streaming) ...[
                      QuietButton(
                        label: 'Steer',
                        tooltip: 'Pi steer',
                        onPressed: enabled
                            ? () => unawaited(_submit(_connection.steer))
                            : null,
                      ),
                      const SizedBox(width: 6),
                      QuietButton(
                        label: 'Follow up',
                        tooltip: 'Pi follow_up',
                        onPressed: enabled
                            ? () => unawaited(_submit(_connection.followUp))
                            : null,
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Abort Pi',
                        onPressed: enabled ? () => unawaited(abort()) : null,
                        icon: const Icon(Icons.stop_circle_outlined),
                      ),
                    ] else
                      SendButton(
                        onPressed: enabled
                            ? () => unawaited(_submit(_connection.prompt))
                            : null,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (landing) ...[
            const SizedBox(height: 10),
            Material(
              color: tokens.panelSoft,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => unawaited(_chooseWorkspace()),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 16,
                        color: tokens.textSoft,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Work in $project',
                          overflow: TextOverflow.ellipsis,
                          style: tokens.control.copyWith(
                            fontSize: 13,
                            color: tokens.textSoft,
                          ),
                        ),
                      ),
                      Text(
                        'Change',
                        style: tokens.control.copyWith(
                          fontSize: 12.5,
                          color: tokens.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (commandSuggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final command in commandSuggestions)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '/${command['name']}',
                        style: tokens.control.copyWith(fontSize: 12),
                      ),
                      backgroundColor: tokens.panelSoft,
                      side: BorderSide(color: tokens.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.chipRadius),
                      ),
                      onPressed: () {
                        _textController.text = '/${command['name']} ';
                        widget.focusNode.requestFocus();
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

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (_textController.value.composing.isValid) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final shift =
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
    if (shift) {
      _insertNewline();
      return KeyEventResult.handled;
    }
    _handleSubmit(_connection.isStreaming);
    return KeyEventResult.handled;
  }

  void _handleSubmit(bool streaming) {
    if (streaming) {
      return;
    }
    unawaited(_submit(_connection.prompt));
  }

  void _insertNewline() {
    _insertAtCursor('\n');
  }

  void _insertAtCursor(String insertion) {
    final value = _textController.value;
    final start = value.selection.start < 0
        ? value.text.length
        : value.selection.start;
    final end = value.selection.end < 0 ? start : value.selection.end;
    final updated = value.text.replaceRange(start, end, insertion);
    _textController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
    setState(() {});
  }

  Future<void> _chooseWorkspace() {
    return chooseWorkspace(
      connection: _connection,
      preferences: widget.preferences,
    );
  }

  Future<void> _attachImages() async {
    try {
      final files = await pickImageFiles();
      if (files.isEmpty) {
        return;
      }
      final added = <_DraftImage>[];
      for (final file in files) {
        final source = await file.readAsBytes();
        final sourceMime = file.mimeType ?? _mimeFromPath(file.name);
        final prepared = await prepareImageForPi(source, sourceMime, file.name);
        added.add(
          _DraftImage(
            label: file.name,
            bytes: prepared.bytes,
            content: <String, dynamic>{
              'type': 'image',
              'data': base64Encode(prepared.bytes),
              'mimeType': prepared.mimeType,
            },
          ),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _images.addAll(added);
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<void> _submit(
    Future<PiRpcResponse> Function(String message, {List<PiJsonObject> images})
    send,
  ) async {
    final draftText = _textController.text;
    final draftImages = List<_DraftImage>.of(_images);
    final message = draftText.trim();
    if (message.isEmpty && _images.isEmpty) {
      return;
    }

    final images = [for (final image in _images) image.content];
    _textController.clear();
    setState(() {
      _images.clear();
      _error = null;
    });
    try {
      final response = await send(message, images: images);
      if (!response.success) {
        // Pi rejected the message (for example a `prompt` racing the
        // stream). Surface the reason and hand the draft back instead of
        // silently discarding user input.
        throw StateError(response.error ?? 'Pi rejected the message.');
      }
      widget.focusNode.requestFocus();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          // A failed RPC transport must not discard user-authored input or
          // attachment preparation work. Pi owns delivery; this restores only
          // the local unsent composer draft.
          if (_textController.text.isEmpty) {
            _textController.text = draftText;
          }
          if (_images.isEmpty) {
            _images.addAll(draftImages);
          }
          _error = error.toString();
        });
      }
    }
  }

  Future<void> abort() async {
    try {
      await _connection.abort();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }
}

class _DraftImage {
  const _DraftImage({
    required this.content,
    required this.label,
    required this.bytes,
  });

  final PiJsonObject content;
  final String label;
  final Uint8List bytes;
}

class PreparedImage {
  const PreparedImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

/// Keeps images within a practical multimodal payload budget. Pi still owns
/// the actual message format; this only prepares pixels selected in the UI.
Future<PreparedImage> prepareImageForPi(
  Uint8List source,
  String sourceMime,
  String label,
) async {
  const maxSourceBytes = 10 * 1024 * 1024;
  const maxPayloadBytes = 6 * 1024 * 1024;
  const maxDimension = 1600;
  if (source.lengthInBytes > maxSourceBytes) {
    throw StateError('$label exceeds 10 MB.');
  }
  // Preserve animated GIFs instead of silently reducing them to one frame.
  if (sourceMime == 'image/gif') {
    return PreparedImage(bytes: source, mimeType: sourceMime);
  }
  final codec = await ui.instantiateImageCodec(source);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      // Use the smaller ratio so neither dimension exceeds the upload bound.
      // Choosing the larger ratio leaves portrait/landscape images untouched.
      final dimensionScale = imageScaleForMaxDimension(
        image.width,
        image.height,
        maxDimension: maxDimension,
      );
      var scale = source.lengthInBytes > maxPayloadBytes && dimensionScale >= 1
          ? 0.75
          : dimensionScale;
      if (scale >= 1) {
        return PreparedImage(bytes: source, mimeType: sourceMime);
      }
      // PNG re-encoding inflates photographic JPEGs; keep shrinking until
      // the payload fits instead of failing on the first attempt.
      for (var attempt = 0; attempt < 4; attempt++) {
        final targetWidth = math.max(1, (image.width * scale).round());
        final targetHeight = math.max(1, (image.height * scale).round());
        final resizedCodec = await ui.instantiateImageCodec(
          source,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );
        try {
          final resized = (await resizedCodec.getNextFrame()).image;
          try {
            final data = await resized.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (data != null && data.lengthInBytes <= maxPayloadBytes) {
              return PreparedImage(
                bytes: data.buffer.asUint8List(),
                mimeType: 'image/png',
              );
            }
          } finally {
            resized.dispose();
          }
        } finally {
          resizedCodec.dispose();
        }
        scale *= 0.7;
      }
      throw StateError('$label remains too large after resizing.');
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

double imageScaleForMaxDimension(
  int width,
  int height, {
  required int maxDimension,
}) {
  return math.min(maxDimension / width, maxDimension / height);
}

class _ImageAttachmentCard extends StatelessWidget {
  const _ImageAttachmentCard({required this.image, required this.onRemove});

  final _DraftImage image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Semantics(
      label: 'Attached image ${image.label}',
      child: Container(
        width: 76,
        height: 60,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: tokens.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.line),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(image.bytes, fit: BoxFit.cover, gaplessPlayback: true),
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: tokens.panel.withValues(alpha: 0.88),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 21,
                    height: 21,
                    child: Icon(Icons.close, size: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachMenu extends StatelessWidget {
  const _AttachMenu({
    required this.tokens,
    required this.onImages,
    required this.onFilesUnavailable,
    required this.onWorkspace,
  });

  final PiTokens tokens;
  final VoidCallback onImages;
  final VoidCallback onFilesUnavailable;
  final VoidCallback onWorkspace;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      consumeOutsideTap: true,
      builder: (context, controller, child) {
        return IconButton(
          tooltip: 'Attach',
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: const Icon(Icons.add, size: 18),
        );
      },
      menuChildren: [
        MenuItemButton(
          onPressed: onImages,
          child: Text('Attach images', style: tokens.control),
        ),
        MenuItemButton(
          onPressed: onFilesUnavailable,
          child: Text('Attach files (needs Pi RPC)', style: tokens.control),
        ),
        MenuItemButton(
          onPressed: onWorkspace,
          child: Text('Choose workspace', style: tokens.control),
        ),
      ],
    );
  }
}

List<PiJsonObject> commandSuggestionsFor(
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
      .take(8)
      .toList(growable: false);
}

String _mimeFromPath(String path) {
  final ext = path.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    _ => 'image/png',
  };
}
