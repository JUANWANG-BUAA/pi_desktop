import 'dart:async';

import 'package:flutter/material.dart';

import '../session/pi_desktop_connection.dart';
import '../session/pi_session_projection.dart';
import 'pi_tokens.dart';

class ExtensionHost extends StatefulWidget {
  const ExtensionHost({
    required this.connection,
    required this.child,
    super.key,
  });

  final PiDesktopConnection connection;
  final Widget child;

  @override
  State<ExtensionHost> createState() => _ExtensionHostState();
}

class _ExtensionHostState extends State<ExtensionHost> {
  late final StreamSubscription<PiJsonObject> _subscription;

  /// Dialog requests currently awaiting a user answer. Pi blocks on each
  /// `extension_ui_response`, so every tracked id must eventually receive
  /// one — including when the window closes mid-dialog.
  final Set<String> _openDialogs = <String>{};

  PiDesktopConnection get _connection => widget.connection;

  @override
  void initState() {
    super.initState();
    _subscription = _connection.extensionUiRequests.listen(
      _handleExtensionUiRequest,
    );
  }

  @override
  void dispose() {
    for (final requestId in _openDialogs) {
      unawaited(_respond(requestId, cancelled: true));
    }
    _openDialogs.clear();
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _handleExtensionUiRequest(PiJsonObject request) async {
    final method = request['method'];
    final requestId = request['id'];
    if (method == 'notify') {
      final message = (request['message'] as String? ?? '').trim();
      if (mounted && message.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    if (requestId is! String) {
      return;
    }
    if (!mounted) {
      await _respond(requestId, cancelled: true);
      return;
    }

    _openDialogs.add(requestId);
    try {
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
            builder: (context) {
              final tokens = PiTokens.of(context);
              return AlertDialog(
                title: Text(request['title'] as String? ?? 'Input'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: method == 'editor' ? 8 : 1,
                  style: method == 'editor' ? tokens.evidence : tokens.reading,
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
              );
            },
          );
          controller.dispose();
          await _respond(requestId, value: value, cancelled: value == null);
        default:
          // Unknown or TUI-only dialog method: answer with the protocol's
          // cancellation semantics instead of leaving Pi waiting forever
          // (TODO.md §7.3).
          await _respond(requestId, cancelled: true);
      }
    } finally {
      _openDialogs.remove(requestId);
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
