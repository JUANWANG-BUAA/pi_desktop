import 'dart:async';

import 'package:flutter/material.dart';

import '../session/pi_desktop_connection.dart';
import '../session/pi_installation.dart';
import 'content_format.dart';
import 'pi_tokens.dart';
import 'pi_session_catalog.dart';
import 'ui_preferences.dart';
import 'widgets.dart';
import 'workspace_io.dart';

class ArchivePane extends StatefulWidget {
  const ArchivePane({
    required this.connection,
    required this.preferences,
    required this.workspacePath,
    required this.currentSessionId,
    this.enableRuntimeInspection = true,
    super.key,
  });

  final PiDesktopConnection connection;
  final UiPreferences preferences;
  final String workspacePath;
  final String? currentSessionId;
  final bool enableRuntimeInspection;

  @override
  State<ArchivePane> createState() => _ArchivePaneState();
}

class _ArchivePaneState extends State<ArchivePane> {
  late Future<List<PiSessionSummary>> _sessions;
  late Future<PiInstallationStatus> _installation;
  var _installing = false;

  @override
  void initState() {
    super.initState();
    _sessions = PiSessionCatalog(widget.workspacePath).load();
    _installation = widget.enableRuntimeInspection
        ? PiInstallation(executable: widget.connection.executable).inspect()
        : Future<PiInstallationStatus>.value(
            const PiInstallationStatus(
              available: false,
              npmAvailable: false,
              detail: 'Pi runtime inspection is disabled',
            ),
          );
  }

  @override
  void didUpdateWidget(covariant ArchivePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspacePath != widget.workspacePath ||
        oldWidget.currentSessionId != widget.currentSessionId) {
      _sessions = PiSessionCatalog(widget.workspacePath).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final connection = widget.connection;
    final preferences = widget.preferences;
    final projection = connection.projection;
    final state = projection?.state;
    final sessionId = state?['sessionId'] as String?;
    final sessionFile = state?['sessionFile'] as String?;
    final sessionName = state?['sessionName'] as String?;
    final messageCount =
        state?['messageCount'] ?? projection?.messages.length ?? 0;
    final title = (sessionName != null && sessionName.trim().isNotEmpty)
        ? sessionName
        : 'Untitled session';

    return ColoredBox(
      color: tokens.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: tokens.accent),
                const SizedBox(width: 8),
                Text(
                  'Pi',
                  style: tokens.control.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 14,
                  color: tokens.textFaint,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: _SidebarButton(
              icon: Icons.add,
              label: 'New task',
              onTap: connection.isConnected
                  ? () => unawaited(connection.newSession())
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
            child: Text('Workspace', style: tokens.micro),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: _WorkspaceRow(
              label: projectLabel(connection.workingDirectory, state),
              onTap: () => unawaited(_showWorkspacePicker(context)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
            child: Row(
              children: [
                Expanded(child: Text('Recents', style: tokens.micro)),
                Tooltip(
                  message: 'Pi switch_session',
                  child: InkWell(
                    onTap: connection.isConnected
                        ? () => unawaited(_showSessionPicker(context))
                        : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.swap_horiz,
                        size: 14,
                        color: tokens.textFaint,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<PiSessionSummary>>(
              future: _sessions,
              builder: (context, snapshot) {
                final sessions = snapshot.data ?? const <PiSessionSummary>[];
                final pinned = sessions
                    .where(
                      (session) =>
                          preferences.pinnedSessionPaths.contains(session.path),
                    )
                    .toList(growable: false);
                final regular = sessions
                    .where(
                      (session) =>
                          !preferences.archivedSessionPaths.contains(
                            session.path,
                          ) &&
                          !preferences.pinnedSessionPaths.contains(
                            session.path,
                          ),
                    )
                    .toList(growable: false);
                final archived = sessions
                    .where(
                      (session) => preferences.archivedSessionPaths.contains(
                        session.path,
                      ),
                    )
                    .toList(growable: false);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  children: [
                    if (sessionId != null)
                      _RecentRow(
                        title: title,
                        subtitle: '$messageCount messages',
                        selected: true,
                        trailing: connection.isConnected
                            ? PopupMenuButton<String>(
                                tooltip: 'Current session actions',
                                icon: const Icon(Icons.more_horiz, size: 16),
                                onSelected: (action) {
                                  if (action == 'rename') {
                                    unawaited(_renameSession(context));
                                  }
                                  if (sessionFile != null && action == 'pin') {
                                    unawaited(
                                      preferences.toggleSessionPinned(
                                        sessionFile,
                                      ),
                                    );
                                  }
                                  if (sessionFile != null &&
                                      action == 'archive') {
                                    unawaited(
                                      preferences.toggleSessionArchived(
                                        sessionFile,
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Rename'),
                                  ),
                                  if (sessionFile != null)
                                    PopupMenuItem(
                                      value: 'pin',
                                      child: Text(
                                        preferences.pinnedSessionPaths.contains(
                                              sessionFile,
                                            )
                                            ? 'Unpin'
                                            : 'Pin',
                                      ),
                                    ),
                                  if (sessionFile != null)
                                    PopupMenuItem(
                                      value: 'archive',
                                      child: Text(
                                        preferences.archivedSessionPaths
                                                .contains(sessionFile)
                                            ? 'Restore from archive'
                                            : 'Archive',
                                      ),
                                    ),
                                ],
                              )
                            : null,
                      ),
                    if (pinned.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 14, 8, 5),
                        child: Text('Pinned', style: tokens.micro),
                      ),
                    for (final session in pinned)
                      if (session.path != projection?.state?['sessionFile'])
                        _SessionRow(
                          session: session,
                          pinned: true,
                          archived: false,
                          onOpen: connection.isConnected
                              ? () => unawaited(
                                  connection.switchSession(session.path),
                                )
                              : null,
                          onPin: () => unawaited(
                            preferences.toggleSessionPinned(session.path),
                          ),
                          onArchive: () => unawaited(
                            preferences.toggleSessionArchived(session.path),
                          ),
                        ),
                    for (final session in regular)
                      if (session.path != projection?.state?['sessionFile'])
                        _SessionRow(
                          session: session,
                          pinned: false,
                          archived: false,
                          onOpen: connection.isConnected
                              ? () => unawaited(
                                  connection.switchSession(session.path),
                                )
                              : null,
                          onPin: () => unawaited(
                            preferences.toggleSessionPinned(session.path),
                          ),
                          onArchive: () => unawaited(
                            preferences.toggleSessionArchived(session.path),
                          ),
                        ),
                    if (archived.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 14, 8, 5),
                        child: Text('Archived', style: tokens.micro),
                      ),
                    for (final session in archived)
                      if (session.path != projection?.state?['sessionFile'])
                        _SessionRow(
                          session: session,
                          pinned: false,
                          archived: true,
                          onOpen: connection.isConnected
                              ? () => unawaited(
                                  connection.switchSession(session.path),
                                )
                              : null,
                          onPin: () => unawaited(
                            preferences.toggleSessionPinned(session.path),
                          ),
                          onArchive: () => unawaited(
                            preferences.toggleSessionArchived(session.path),
                          ),
                        ),
                    if (sessionId == null && sessions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Text(
                          'No Pi Session loaded',
                          style: tokens.control.copyWith(
                            color: tokens.textFaint,
                            height: 1.4,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            child: FutureBuilder<PiInstallationStatus>(
              future: _installation,
              builder: (context, snapshot) => _PiRuntimeStatus(
                status: snapshot.data,
                connecting: connection.isConnecting,
                connected: connection.isConnected,
                installing: _installing,
                onConnect: () => unawaited(connection.restart()),
                onInstall: () => unawaited(_installPi(context, snapshot.data)),
                onRefresh: () => setState(
                  () => _installation = PiInstallation(
                    executable: widget.connection.executable,
                  ).inspect(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSessionPicker(BuildContext context) async {
    final sessions = await PiSessionCatalog(widget.workspacePath).load();
    if (!context.mounted || sessions.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No Pi sessions found for this workspace.'),
          ),
        );
      }
      return;
    }
    String query = '';
    final selected = await showDialog<Object>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = sessions
              .where((session) {
                final needle = query.trim().toLowerCase();
                return needle.isEmpty ||
                    session.title.toLowerCase().contains(needle) ||
                    session.path.toLowerCase().contains(needle);
              })
              .toList(growable: false);
          return AlertDialog(
            title: const Text('Open Pi session'),
            content: SizedBox(
              width: 520,
              height: 380,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (value) => setDialogState(() => query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search this workspace',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final session = filtered[index];
                        return ListTile(
                          title: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(_relativeTime(session.modified)),
                          onTap: () => Navigator.pop(context, session),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _SessionOpenAction.enterPath),
                child: const Text('Enter path…'),
              ),
            ],
          );
        },
      ),
    );
    if (!context.mounted) return;
    if (selected is PiSessionSummary) {
      await widget.connection.switchSession(selected.path);
      return;
    }
    if (selected == _SessionOpenAction.enterPath) {
      await _switchSessionByPath(context);
    }
  }

  Future<void> _switchSessionByPath(BuildContext context) async {
    final controller = TextEditingController(
      text:
          widget.connection.projection?.state?['sessionFile'] as String? ?? '',
    );
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
    await widget.connection.switchSession(path.trim());
  }

  Future<void> _renameSession(BuildContext context) async {
    final current =
        widget.connection.projection?.state?['sessionName'] as String? ?? '';
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Pi Session'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Session name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) {
      return;
    }
    await widget.connection.setSessionName(name.trim());
  }

  Future<void> _installPi(
    BuildContext context,
    PiInstallationStatus? status,
  ) async {
    if (_installing || status?.npmAvailable != true) return;
    final verb = status?.available == true ? 'Update' : 'Install';
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$verb Pi'),
        content: const Text(
          'This runs the official command:\n\nnpm install --global --ignore-scripts @earendil-works/pi-coding-agent\n\nIt changes your global npm installation. Pi Desktop will not install extensions or start an additional agent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(verb),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _installing = true);
    final result = await PiInstallation(
      executable: widget.connection.executable,
    ).installOrUpdate();
    if (!mounted) return;
    setState(() {
      _installing = false;
      _installation = PiInstallation(executable: widget.connection.executable)
          .inspect();
    });
    if (result.ok) {
      unawaited(widget.connection.restart());
    } else {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(
            result.output.isEmpty ? 'Pi installation failed.' : result.output,
          ),
        ),
      );
    }
  }

  Future<void> _showWorkspacePicker(BuildContext context) async {
    final current = widget.connection.workingDirectory;
    final recent = widget.preferences.recentWorkspacePaths
        .where((path) => path != current)
        .toList(growable: false);
    final choice = await showDialog<_WorkspaceChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch workspace'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pi reconnects directly in the selected folder. Recent workspaces are local UI preferences only.',
                style: PiTokens.of(context).control.copyWith(
                  color: PiTokens.of(context).textSoft,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Current · $current',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              if (recent.isNotEmpty)
                for (final path in recent)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.history, size: 17),
                    title: Text(projectLabel(path, null)),
                    subtitle: Text(
                      path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () =>
                        Navigator.pop(context, _WorkspaceChoice.path(path)),
                  )
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('No other recent workspaces yet.'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, const _WorkspaceChoice.chooseFolder()),
            icon: const Icon(Icons.folder_open_outlined, size: 17),
            label: const Text('Choose folder'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice.useFolderPicker) {
      await chooseWorkspace(
        connection: widget.connection,
        preferences: widget.preferences,
      );
      return;
    }
    final path = choice.path;
    if (path == null || path == current) return;
    await widget.connection.reconnectIn(path);
    await widget.preferences.setWorkspacePath(path);
  }
}

class _WorkspaceChoice {
  const _WorkspaceChoice.path(this.path) : useFolderPicker = false;
  const _WorkspaceChoice.chooseFolder() : path = null, useFolderPicker = true;

  final String? path;
  final bool useFolderPicker;
}

class _PiRuntimeStatus extends StatelessWidget {
  const _PiRuntimeStatus({
    required this.status,
    required this.connecting,
    required this.connected,
    required this.installing,
    required this.onConnect,
    required this.onInstall,
    required this.onRefresh,
  });

  final PiInstallationStatus? status;
  final bool connecting;
  final bool connected;
  final bool installing;
  final VoidCallback onConnect;
  final VoidCallback onInstall;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final state = status;
    final label = state == null
        ? 'Checking Pi…'
        : state.available
        ? 'Pi ${state.installedVersion ?? ''}'.trim()
        : 'Pi not installed';
    final detail = state?.detail ?? 'Checking local runtime';
    return Row(
      children: [
        Icon(Icons.auto_awesome, size: 16, color: tokens.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tokens.control.copyWith(fontSize: 12.5)),
              Text(
                detail,
                overflow: TextOverflow.ellipsis,
                style: tokens.micro,
              ),
            ],
          ),
        ),
        if (state?.updateAvailable == true)
          TextButton(
            onPressed: installing ? null : onInstall,
            child: Text(installing ? 'Working…' : 'Update'),
          )
        else if (state?.available == true && !connected)
          IconButton(
            tooltip: 'Connect to Pi RPC',
            onPressed: connecting ? null : onConnect,
            icon: const Icon(Icons.refresh_outlined, size: 16),
          )
        else if (state?.npmAvailable == true && !connected)
          TextButton(
            onPressed: installing ? null : onInstall,
            child: Text(
              installing
                  ? 'Working…'
                  : state?.available == true
                  ? 'Update'
                  : 'Install',
            ),
          )
        else
          StatusDot(color: connected ? tokens.signalOk : tokens.textFaint),
        IconButton(
          tooltip: 'Refresh Pi version',
          visualDensity: VisualDensity.compact,
          onPressed: installing ? null : onRefresh,
          icon: const Icon(Icons.refresh_outlined, size: 15),
        ),
      ],
    );
  }
}

String _relativeTime(DateTime value) {
  final age = DateTime.now().difference(value);
  if (age.inMinutes < 1) return 'just now';
  if (age.inHours < 1) return '${age.inMinutes}m ago';
  if (age.inDays < 1) return '${age.inHours}h ago';
  return '${age.inDays}d ago';
}

enum _SessionOpenAction { enterPath }

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: tokens.text),
              const SizedBox(width: 10),
              Text(label, style: tokens.control.copyWith(fontSize: 13.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Semantics(
      key: const Key('workspace-switcher'),
      button: true,
      label: 'Switch workspace',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, size: 15, color: tokens.textFaint),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.control.copyWith(
                      fontSize: 12.5,
                      color: tokens.textSoft,
                    ),
                  ),
                ),
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 14,
                  color: tokens.textFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 2, 8),
          decoration: BoxDecoration(
            color: selected ? tokens.panelSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.control.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.control.copyWith(
                        color: tokens.textFaint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing! else const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.pinned,
    required this.archived,
    required this.onOpen,
    required this.onPin,
    required this.onArchive,
  });

  final PiSessionSummary session;
  final bool pinned;
  final bool archived;
  final VoidCallback? onOpen;
  final VoidCallback onPin;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return _RecentRow(
      title: session.title,
      subtitle: _relativeTime(session.modified),
      selected: false,
      onTap: onOpen,
      trailing: PopupMenuButton<String>(
        tooltip: 'Session actions',
        icon: const Icon(Icons.more_horiz, size: 16),
        onSelected: (action) {
          if (action == 'pin') onPin();
          if (action == 'archive') onArchive();
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'pin', child: Text(pinned ? 'Unpin' : 'Pin')),
          PopupMenuItem(
            value: 'archive',
            child: Text(archived ? 'Restore from archive' : 'Archive'),
          ),
        ],
      ),
    );
  }
}
