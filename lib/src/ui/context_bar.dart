import 'dart:async';

import 'package:flutter/material.dart';

import '../rpc/pi_rpc_client.dart';
import '../session/pi_desktop_connection.dart';
import 'pi_tokens.dart';
import 'ui_preferences.dart';
import 'widgets.dart';
import 'workspace_io.dart';

class ContextBar extends StatelessWidget {
  const ContextBar({
    required this.connection,
    required this.preferences,
    required this.onToggleInspector,
    required this.onOpenSettings,
    this.archiveTemporarilyHidden = false,
    this.inspectorTemporarilyHidden = false,
    super.key,
  });

  final PiDesktopConnection connection;
  final UiPreferences preferences;
  final VoidCallback onToggleInspector;
  final VoidCallback onOpenSettings;
  final bool archiveTemporarilyHidden;
  final bool inspectorTemporarilyHidden;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final projection = connection.projection;
    final sessionName = projection?.state?['sessionName'] as String?;
    final title =
        connection.extensionTitle ??
        (sessionName != null && sessionName.trim().isNotEmpty
            ? sessionName
            : projection?.state?['sessionId'] != null
            ? 'New session'
            : 'Pi Desktop');
    final streaming = connection.isStreaming;
    final status = statusView(connection.status, streaming, tokens);

    return Semantics(
      container: true,
      label: 'Pi session context',
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (!preferences.archiveVisible)
                IconButton(
                  tooltip: 'Show Sessions',
                  onPressed: () => unawaited(preferences.toggleArchive()),
                  icon: const Icon(Icons.view_sidebar_outlined, size: 16),
                ),
              if (archiveTemporarilyHidden)
                IconButton(
                  tooltip: 'Widen window to show sessions',
                  onPressed: null,
                  icon: const Icon(Icons.view_sidebar_outlined, size: 16),
                ),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.control.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
              if (streaming)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'Streaming',
                    style: tokens.control.copyWith(
                      color: tokens.accent,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (connection.errorMessage != null) ...[
                Icon(Icons.error_outline, size: 15, color: tokens.signalDanger),
                const SizedBox(width: 8),
              ],
              StatusDot(color: status.color, size: 6),
              if (connection.status != PiConnectionStatus.connected &&
                  connection.status != PiConnectionStatus.connecting)
                IconButton(
                  tooltip: connection.status == PiConnectionStatus.crashed
                      ? 'Restart Pi RPC'
                      : 'Connect to Pi RPC',
                  onPressed: () => unawaited(connection.restart()),
                  icon: const Icon(Icons.refresh_outlined, size: 16),
                ),
              _SessionMenu(connection: connection, preferences: preferences),
              IconButton(
                tooltip:
                    preferences.inspectorVisible && !inspectorTemporarilyHidden
                    ? 'Hide Pi details'
                    : 'Show Pi details, tools and commands',
                onPressed: inspectorTemporarilyHidden
                    ? null
                    : onToggleInspector,
                icon: Icon(
                  preferences.inspectorVisible && !inspectorTemporarilyHidden
                      ? Icons.close_fullscreen_outlined
                      : Icons.open_in_full_outlined,
                  size: 17,
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined, size: 16),
              ),
              IconButton(
                tooltip: preferences.themeMode == ThemeMode.dark
                    ? 'Switch to light display'
                    : 'Switch to dark display',
                onPressed: () => unawaited(preferences.cycleThemeMode()),
                icon: Icon(
                  preferences.themeMode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionMenu extends StatelessWidget {
  const _SessionMenu({required this.connection, required this.preferences});

  final PiDesktopConnection connection;
  final UiPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final enabled = connection.isConnected;
    return MenuAnchor(
      consumeOutsideTap: true,
      builder: (context, controller, child) {
        return IconButton(
          tooltip: 'Session actions',
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: const Icon(Icons.more_horiz, size: 16),
        );
      },
      menuChildren: [
        MenuItemButton(
          onPressed: () => unawaited(
            chooseWorkspace(connection: connection, preferences: preferences),
          ),
          child: Text('Choose workspace', style: tokens.control),
        ),
        for (final workspace in preferences.recentWorkspacePaths)
          MenuItemButton(
            onPressed: () => unawaited(
              connection
                  .reconnectIn(workspace)
                  .then((_) => preferences.setWorkspacePath(workspace)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    workspace,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.control,
                  ),
                ),
              ],
            ),
          ),
        MenuItemButton(
          onPressed: enabled ? () => unawaited(connection.clone()) : null,
          child: Text('Clone session', style: tokens.control),
        ),
        MenuItemButton(
          onPressed: enabled ? () => unawaited(connection.compact()) : null,
          child: Text('Compact', style: tokens.control),
        ),
        MenuItemButton(
          onPressed: enabled ? () => unawaited(_export(context)) : null,
          child: Text('Export HTML', style: tokens.control),
        ),
        MenuItemButton(
          onPressed: enabled ? () => unawaited(connection.abortRetry()) : null,
          child: Text('Abort retry', style: tokens.control),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context) async {
    PiRpcResponse response;
    try {
      response = await connection.exportHtml();
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Pi export failed: $error')));
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    final data = response.data;
    final path = data is Map ? data['path'] as String? : null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.success
              ? (path == null ? 'Exported HTML' : 'Exported $path')
              : (response.error ?? 'Export failed'),
        ),
      ),
    );
  }
}

class StatusView {
  const StatusView(this.label, this.color);

  final String label;
  final Color color;
}

StatusView statusView(
  PiConnectionStatus status,
  bool streaming,
  PiTokens tokens,
) {
  if (streaming) {
    return StatusView('streaming', tokens.accent);
  }
  return switch (status) {
    PiConnectionStatus.disconnected => StatusView(
      'disconnected',
      tokens.textFaint,
    ),
    PiConnectionStatus.connecting => StatusView('connecting', tokens.accent),
    PiConnectionStatus.connected => StatusView('connected', tokens.signalOk),
    PiConnectionStatus.stopping => StatusView('stopping', tokens.textFaint),
    PiConnectionStatus.crashed => StatusView(
      'Pi RPC exited',
      tokens.signalDanger,
    ),
  };
}
