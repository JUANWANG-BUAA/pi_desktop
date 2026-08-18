import 'dart:async';

import 'package:flutter/material.dart';

import '../rpc/pi_rpc_client.dart';
import '../session/pi_desktop_connection.dart';
import '../session/pi_session_projection.dart';
import 'content_format.dart';
import 'markdown_document.dart';
import 'pi_tokens.dart';
import 'pi_resource_catalog.dart';
import 'workspace_file_catalog.dart';
import 'widgets.dart';

class InspectorPane extends StatefulWidget {
  const InspectorPane({required this.connection, super.key});

  final PiDesktopConnection connection;

  @override
  State<InspectorPane> createState() => _InspectorPaneState();
}

class _InspectorPaneState extends State<InspectorPane>
    with SingleTickerProviderStateMixin {
  String? _actionError;
  String? _exportPath;
  late final TabController _tabs;

  PiDesktopConnection get _connection => widget.connection;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final projection = _connection.projection;

    return Material(
      color: tokens.panel,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Inspector',
                style: tokens.control.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          _InspectorStatusStrip(
            connection: _connection,
            projection: projection,
          ),
          TabBar(
            controller: _tabs,
            isScrollable: false,
            labelPadding: EdgeInsets.zero,
            tabs: const [
              Tab(text: 'Activity'),
              Tab(text: 'Files'),
              Tab(text: 'Session'),
              Tab(text: 'Tools'),
              Tab(text: 'Preview'),
            ],
          ),
          if (_actionError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text(
                _actionError!,
                style: tokens.control.copyWith(color: tokens.signalDanger),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ActivityTab(connection: _connection, projection: projection),
                _TreeTab(
                  projection: projection,
                  workspacePath: _connection.workingDirectory,
                ),
                _SessionTab(
                  connection: _connection,
                  projection: projection,
                  exportPath: _exportPath,
                  onAction: _runAction,
                  onExport: _export,
                ),
                _CapabilitiesTab(
                  connection: _connection,
                  projection: projection,
                ),
                _PreviewTab(projection: projection),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    final response = await _runAction(() => _connection.exportHtml());
    final data = response?.data;
    if (data is Map && data['path'] is String && mounted) {
      setState(() => _exportPath = data['path'] as String);
    }
  }

  Future<PiRpcResponse?> _runAction(
    Future<PiRpcResponse> Function() action,
  ) async {
    try {
      final response = await action();
      if (!response.success && mounted) {
        setState(() => _actionError = response.error ?? 'Pi command failed');
      } else if (response.cancelledByExtension && mounted) {
        // `fork` / `switch_session` report success with `cancelled: true`
        // when a Pi extension vetoes them; show that instead of silently
        // behaving as if the action happened.
        setState(() => _actionError = 'A Pi extension cancelled this action.');
      } else if (mounted) {
        setState(() => _actionError = null);
      }
      return response;
    } on Object catch (error) {
      if (mounted) {
        setState(() => _actionError = error.toString());
      }
      return null;
    }
  }
}

class _InspectorStatusStrip extends StatelessWidget {
  const _InspectorStatusStrip({
    required this.connection,
    required this.projection,
  });

  final PiDesktopConnection connection;
  final PiSessionProjection? projection;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final usage = projection?.sessionStats?['contextUsage'];
    final percent = usage is Map ? usage['percent'] as num? : null;
    final label = !connection.isConnected
        ? 'offline'
        : projection?.isStreaming == true
        ? 'working'
        : 'ready';
    final color = !connection.isConnected
        ? tokens.textFaint
        : projection?.isStreaming == true
        ? tokens.accent
        : tokens.signalOk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          StatusDot(color: color, size: 6),
          const SizedBox(width: 7),
          Text(label, style: tokens.micro.copyWith(color: tokens.textSoft)),
          const Spacer(),
          if (percent != null)
            Text(
              'context ${percent.round()}%',
              style: tokens.micro.copyWith(
                color: percent >= 80 ? tokens.signalWarn : tokens.textFaint,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.connection, required this.projection});

  final PiDesktopConnection connection;
  final PiSessionProjection? projection;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final tools = projection?.toolEvents ?? const <PiJsonObject>[];
    final timeline = projection?.timelineEvents ?? const <PiJsonObject>[];
    final streaming = projection?.isStreaming == true;
    final queue =
        (projection?.steeringQueue.length ?? 0) +
        (projection?.followUpQueue.length ?? 0);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            StatusDot(
              size: 7,
              color: streaming ? tokens.accent : tokens.signalOk,
            ),
            const SizedBox(width: 8),
            Text(
              streaming ? 'Pi is working' : 'Pi is ready',
              style: tokens.control.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          streaming
              ? 'Live progress is projected from Pi RPC events.'
              : 'Activity is retained only for the current Pi session.',
          style: tokens.control.copyWith(color: tokens.textSoft, fontSize: 12),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Progress'),
        if (tools.isEmpty && timeline.isEmpty)
          Text(
            'No tool or lifecycle events have been reported yet.',
            style: tokens.control.copyWith(color: tokens.textFaint),
          ),
        for (final event in tools.reversed.take(20))
          _ActivityEventRow(event: event, tool: true),
        for (final event in timeline.reversed.take(20))
          _ActivityEventRow(event: event, tool: false),
        const SizedBox(height: 16),
        const SectionLabel('Context'),
        _ActivityMeta(
          icon: Icons.folder_outlined,
          label: 'Workspace',
          value: connection.workingDirectory,
        ),
        _ActivityMeta(
          icon: Icons.account_tree_outlined,
          label: 'Session',
          value: sessionLabel(projection?.state),
        ),
        _ActivityMeta(
          icon: Icons.pending_actions_outlined,
          label: 'Queue',
          value: queue == 0
              ? 'No pending messages'
              : '$queue pending message${queue == 1 ? '' : 's'}',
        ),
        if (projection?.streamingThinking?.isNotEmpty == true)
          FoldBlock(
            title: 'Live thinking',
            child: SelectableText(
              projection!.streamingThinking!,
              style: tokens.reading.copyWith(
                color: tokens.textSoft,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActivityEventRow extends StatelessWidget {
  const _ActivityEventRow({required this.event, required this.tool});

  final PiJsonObject event;
  final bool tool;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final type = event['type'] as String? ?? 'Pi event';
    final name = tool ? event['toolName'] as String? ?? 'tool' : type;
    final detail = tool
        ? type
        : event['reason'] as String? ?? event['error'] as String? ?? '';
    final errored = event['isError'] == true || event['error'] != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      decoration: BoxDecoration(
        color: tokens.panelSoft,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.chipRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            tool ? Icons.build_outlined : Icons.radio_button_checked,
            size: 15,
            color: errored ? tokens.signalDanger : tokens.textFaint,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.evidence.copyWith(fontSize: 12),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.control.copyWith(
                      color: tokens.textSoft,
                      fontSize: 11.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityMeta extends StatelessWidget {
  const _ActivityMeta({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: tokens.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tokens.micro),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.control.copyWith(
                    color: tokens.textSoft,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A transparent capability surface: it only presents the tools that ship in
/// Pi plus commands and extension status reported by the connected Pi process.
/// It deliberately does not load, proxy, or schedule any extra agent runtime.
class _CapabilitiesTab extends StatefulWidget {
  const _CapabilitiesTab({required this.connection, required this.projection});

  final PiDesktopConnection connection;
  final PiSessionProjection? projection;

  @override
  State<_CapabilitiesTab> createState() => _CapabilitiesTabState();
}

class _CapabilitiesTabState extends State<_CapabilitiesTab> {
  late Future<PiResourceSnapshot> _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = PiResourceCatalog(
      workspacePath: widget.connection.workingDirectory,
    ).discover();
  }

  void _refreshCatalog() {
    setState(() {
      _catalog = PiResourceCatalog(
        workspacePath: widget.connection.workingDirectory,
      ).discover();
    });
  }

  static const _builtIns = <({String name, String description, IconData icon})>[
    (
      name: 'read',
      description: 'Read file contents',
      icon: Icons.article_outlined,
    ),
    (
      name: 'bash',
      description: 'Execute shell commands',
      icon: Icons.terminal_outlined,
    ),
    (
      name: 'edit',
      description: 'Apply targeted edits',
      icon: Icons.edit_outlined,
    ),
    (
      name: 'write',
      description: 'Create or overwrite files',
      icon: Icons.edit_note_outlined,
    ),
    (
      name: 'grep',
      description: 'Search file contents',
      icon: Icons.manage_search_outlined,
    ),
    (
      name: 'find',
      description: 'Find files by glob',
      icon: Icons.folder_open_outlined,
    ),
    (
      name: 'ls',
      description: 'List directories',
      icon: Icons.list_alt_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final commands = widget.projection?.commands ?? const <PiJsonObject>[];
    final statuses = widget.connection.extensionStatuses.entries.toList();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          'Pi capabilities',
          style: tokens.control.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          'Shown from the Pi installation and this RPC session. This panel never adds a harness or a second agent.',
          style: tokens.control.copyWith(color: tokens.textSoft, fontSize: 12),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Built-in tools'),
        for (final tool in _builtIns)
          _CapabilityRow(
            name: tool.name,
            detail: tool.description,
            icon: tool.icon,
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: const SectionLabel('Installed Pi resources')),
            IconButton(
              tooltip: 'Refresh local Pi resources',
              onPressed: _refreshCatalog,
              icon: const Icon(Icons.refresh_outlined, size: 16),
            ),
          ],
        ),
        FutureBuilder<PiResourceSnapshot>(
          future: _catalog,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Reading Pi resources…',
                  style: tokens.control.copyWith(color: tokens.textFaint),
                ),
              );
            }
            final resources = snapshot.data;
            if (resources == null) {
              return Text(
                'Local Pi resources are unavailable.',
                style: tokens.control.copyWith(color: tokens.textFaint),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ResourceGroup(
                  'Skills',
                  resources.skills,
                  Icons.psychology_outlined,
                ),
                _ResourceGroup(
                  'Extensions',
                  resources.extensions,
                  Icons.extension_outlined,
                ),
                _ResourceGroup(
                  'Prompts',
                  resources.prompts,
                  Icons.short_text_outlined,
                ),
                _ResourceGroup(
                  'Themes',
                  resources.themes,
                  Icons.palette_outlined,
                ),
                _ResourceGroup(
                  'MCP servers',
                  resources.mcps,
                  Icons.hub_outlined,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        const SectionLabel('Desktop extension slots'),
        Text(
          'Pi extensions remain the only extension runtime. When an installed Pi extension emits an official RPC UI request, Pi Desktop presents it and returns the response to that same Pi process.',
          style: tokens.control.copyWith(color: tokens.textSoft, fontSize: 12),
        ),
        const SizedBox(height: 8),
        const _CapabilityRow(
          name: 'Status + inline widget',
          detail: 'setStatus · setWidget',
          icon: Icons.space_dashboard_outlined,
        ),
        const _CapabilityRow(
          name: 'Composer seed + title',
          detail: 'set_editor_text · setTitle',
          icon: Icons.edit_note_outlined,
        ),
        const _CapabilityRow(
          name: 'Native prompt surface',
          detail: 'notify · select · confirm · input · editor',
          icon: Icons.forum_outlined,
        ),
        const SizedBox(height: 14),
        SectionLabel('Slash commands · ${commands.length}'),
        if (commands.isEmpty)
          Text(
            'No commands reported by Pi yet.',
            style: tokens.control.copyWith(color: tokens.textFaint),
          )
        else
          for (final command in commands.take(30))
            _CapabilityRow(
              name: '/${command['name'] ?? 'command'}',
              detail: command['description'] as String? ?? 'Pi command',
              icon: Icons.bolt_outlined,
            ),
        const SizedBox(height: 14),
        SectionLabel('Extensions / MCP status · ${statuses.length}'),
        if (statuses.isEmpty)
          Text(
            'No extension status has been reported by Pi. Installed package discovery remains Pi-owned.',
            style: tokens.control.copyWith(color: tokens.textFaint),
          )
        else
          for (final entry in statuses)
            _CapabilityRow(
              name: entry.key,
              detail: entry.value,
              icon: Icons.extension_outlined,
            ),
      ],
    );
  }
}

class _ResourceGroup extends StatelessWidget {
  const _ResourceGroup(this.label, this.resources, this.icon);

  final String label;
  final List<PiResourceEntry> resources;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (resources.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('$label · ${resources.length}'),
        for (final resource in resources)
          _CapabilityRow(
            name: resource.name,
            detail: '${resource.scope} · ${resource.detail}',
            icon: icon,
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({
    required this.name,
    required this.detail,
    required this.icon,
  });

  final String name;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.panelSoft,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.chipRadius),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: tokens.textFaint),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.evidence.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.control.copyWith(
                    fontSize: 11.5,
                    color: tokens.textSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTab extends StatelessWidget {
  const _SessionTab({
    required this.connection,
    required this.projection,
    required this.exportPath,
    required this.onAction,
    required this.onExport,
  });

  final PiDesktopConnection connection;
  final PiSessionProjection? projection;
  final String? exportPath;
  final Future<PiRpcResponse?> Function(Future<PiRpcResponse> Function() action)
  onAction;
  final Future<void> Function() onExport;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
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
    final steeringMode = projection?.state?['steeringMode'] as String?;
    final followUpMode = projection?.state?['followUpMode'] as String?;
    final autoCompaction = projection?.state?['autoCompactionEnabled'] == true;
    final forkMessages = projection?.forkMessages ?? const <PiJsonObject>[];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (!connection.isConnected)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Inspector reads Pi state after RPC connects.',
              style: tokens.control.copyWith(color: tokens.textSoft),
            ),
          ),
        const SectionLabel('Stream'),
        MetaRow(
          label: 'state',
          value: projection?.isStreaming == true ? 'active' : 'idle',
        ),
        MetaRow(label: 'event', value: projection?.lastEventType ?? 'none'),
        MetaRow(
          label: 'messages',
          value: '${projection?.messages.length ?? 0}',
        ),
        MetaRow(
          label: 'queue',
          value:
              'steer ${projection?.steeringQueue.length ?? 0} · follow-up ${projection?.followUpQueue.length ?? 0}',
        ),
        if (exportPath != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Exported $exportPath',
              style: tokens.evidence.copyWith(color: tokens.signalOk),
            ),
          ),
        const SectionLabel('Usage'),
        MetaRow(
          label: 'current',
          value: projection?.sessionStats == null
              ? 'Not reported yet'
              : usageLabel(projection!.sessionStats!),
        ),
        if (projection?.liveUsage != null)
          MetaRow(
            label: 'live',
            value: streamUsageLabel(projection!.liveUsage!),
          ),
        if (projection?.bashOutput?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          const SectionLabel('RPC bash'),
          CodeSurface(text: projection!.bashOutput!),
        ],
        if (connection.stderrLines.isNotEmpty) ...[
          const SizedBox(height: 12),
          FoldBlock(
            title: 'Pi stderr',
            child: CodeSurface(
              text: connection.stderrLines.join('\n'),
              color: tokens.signalWarn,
            ),
          ),
        ],
        const SectionLabel('Model'),
        PiSelect<String>(
          value: selectedModel,
          hint: 'Select model',
          items: modelValues,
          onChanged: connection.isConnected
              ? (value) {
                  if (value == null) {
                    return;
                  }
                  final separator = value.indexOf('/');
                  if (separator <= 0) {
                    return;
                  }
                  unawaited(
                    onAction(
                      () => connection.setModel(
                        value.substring(0, separator),
                        value.substring(separator + 1),
                      ),
                    ),
                  );
                }
              : null,
        ),
        const SizedBox(height: 14),
        const SectionLabel('Thinking level'),
        PiSelect<String>(
          value: selectedThinking,
          hint: 'Select thinking level',
          items: thinkingLevels,
          onChanged: connection.isConnected
              ? (level) {
                  if (level != null) {
                    unawaited(
                      onAction(() => connection.setThinkingLevel(level)),
                    );
                  }
                }
              : null,
        ),
        const SizedBox(height: 14),
        const SectionLabel('Queue modes'),
        PiSelect<String>(
          value: const {'all', 'one-at-a-time'}.contains(steeringMode)
              ? steeringMode
              : null,
          hint: 'Steering mode',
          items: const <String>['all', 'one-at-a-time'],
          onChanged: connection.isConnected
              ? (mode) {
                  if (mode != null) {
                    unawaited(onAction(() => connection.setSteeringMode(mode)));
                  }
                }
              : null,
        ),
        const SizedBox(height: 8),
        PiSelect<String>(
          value: const {'all', 'one-at-a-time'}.contains(followUpMode)
              ? followUpMode
              : null,
          hint: 'Follow-up mode',
          items: const <String>['all', 'one-at-a-time'],
          onChanged: connection.isConnected
              ? (mode) {
                  if (mode != null) {
                    unawaited(onAction(() => connection.setFollowUpMode(mode)));
                  }
                }
              : null,
        ),
        const SizedBox(height: 14),
        const SectionLabel('Compaction / Retry'),
        _FlagRow(
          label: 'Auto compaction',
          value: autoCompaction,
          onChanged: connection.isConnected
              ? (value) => unawaited(
                  onAction(() => connection.setAutoCompaction(value)),
                )
              : null,
        ),
        const SizedBox(height: 8),
        QuietButton(
          label: 'Abort retry',
          tooltip: 'Pi abort_retry',
          onPressed: connection.isConnected
              ? () => unawaited(onAction(connection.abortRetry))
              : null,
        ),
        const SizedBox(height: 16),
        const SectionLabel('Actions'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            QuietButton(
              label: 'Clone',
              tooltip: 'Pi clone',
              onPressed: connection.isConnected
                  ? () => unawaited(onAction(connection.clone))
                  : null,
            ),
            QuietButton(
              label: 'Compact',
              tooltip: 'Pi compact',
              onPressed: connection.isConnected
                  ? () => unawaited(onAction(() => connection.compact()))
                  : null,
            ),
            QuietButton(
              label: 'Export',
              tooltip: 'Pi export_html',
              onPressed: connection.isConnected
                  ? () => unawaited(onExport())
                  : null,
            ),
            QuietButton(
              label: 'Stats',
              tooltip: 'Pi get_session_stats',
              onPressed: connection.isConnected
                  ? () => unawaited(onAction(connection.getSessionStats))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SectionLabel('Fork'),
        if (forkMessages.isEmpty)
          Text(
            'No user messages available for Pi fork.',
            style: tokens.control.copyWith(color: tokens.textSoft),
          )
        else
          for (final item in forkMessages)
            _ForkRow(
              entryId: item['entryId'] as String? ?? '',
              text: item['text'] as String? ?? '',
              enabled: connection.isConnected,
              onFork: (id) => unawaited(onAction(() => connection.fork(id))),
            ),
      ],
    );
  }
}

class _TreeTab extends StatefulWidget {
  const _TreeTab({required this.projection, required this.workspacePath});

  final PiSessionProjection? projection;
  final String workspacePath;

  @override
  State<_TreeTab> createState() => _TreeTabState();
}

class _TreeTabState extends State<_TreeTab> {
  late Future<List<WorkspaceFileEntry>> _files;

  @override
  void initState() {
    super.initState();
    _files = WorkspaceFileCatalog(widget.workspacePath).load();
  }

  @override
  void didUpdateWidget(covariant _TreeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspacePath != widget.workspacePath) {
      _files = WorkspaceFileCatalog(widget.workspacePath).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final treeEntries = flattenTree(widget.projection?.tree?['tree']);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            const Expanded(child: SectionLabel('Workspace files')),
            IconButton(
              tooltip: 'Refresh workspace files',
              onPressed: () => setState(() {
                _files = WorkspaceFileCatalog(widget.workspacePath).load();
              }),
              icon: const Icon(Icons.refresh_outlined, size: 16),
            ),
          ],
        ),
        Text(
          widget.workspacePath,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tokens.control.copyWith(
            color: tokens.textFaint,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<WorkspaceFileEntry>>(
          future: _files,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Text(
                'Reading workspace…',
                style: tokens.control.copyWith(color: tokens.textFaint),
              );
            }
            final files = snapshot.data ?? const <WorkspaceFileEntry>[];
            if (files.isEmpty) {
              return Text(
                'No readable top-level workspace files.',
                style: tokens.control.copyWith(color: tokens.textFaint),
              );
            }
            return Column(
              children: [
                for (final entry in files)
                  _WorkspaceFileRow(
                    entry: entry,
                    onPreview: entry.directory
                        ? null
                        : () => _showPreview(context, entry),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const SectionLabel('Pi session tree'),
        if (treeEntries.isEmpty)
          Text(
            'Pi returned no session tree entries.',
            style: tokens.control.copyWith(color: tokens.textSoft),
          ),
        for (final item in treeEntries)
          Padding(
            padding: EdgeInsets.only(left: item.depth * 12, bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.role,
                  style: tokens.micro.copyWith(color: tokens.accent),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  item.label ?? item.id,
                  style: tokens.evidence.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showPreview(BuildContext context, WorkspaceFileEntry entry) {
    showDialog<void>(
      context: context,
      builder: (context) => _WorkspacePreviewDialog(entry: entry),
    );
  }
}

class _WorkspaceFileRow extends StatelessWidget {
  const _WorkspaceFileRow({required this.entry, required this.onPreview});

  final WorkspaceFileEntry entry;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPreview,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Row(
            children: [
              Icon(
                entry.directory
                    ? Icons.folder_outlined
                    : Icons.description_outlined,
                size: 15,
                color: tokens.textFaint,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.name,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.control.copyWith(fontSize: 12),
                ),
              ),
              if (!entry.directory)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: tokens.textFaint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspacePreviewDialog extends StatelessWidget {
  const _WorkspacePreviewDialog({required this.entry});

  final WorkspaceFileEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return AlertDialog(
      title: Text(entry.name),
      content: SizedBox(
        width: 680,
        height: 480,
        child: FutureBuilder<WorkspaceFilePreview>(
          future: WorkspaceFilePreview.read(entry.path),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final preview = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: CodeSurface(text: preview.text),
                  ),
                ),
                if (preview.truncated)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Preview limited to the first 96 KB.',
                      style: tokens.control.copyWith(
                        color: tokens.textFaint,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Read-only rendering of the newest assistant text Pi has projected. It is a
/// convenience viewport over the message already owned by Pi, not a document
/// editor or a parallel conversation store.
class _PreviewTab extends StatelessWidget {
  const _PreviewTab({required this.projection});

  final PiSessionProjection? projection;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    PiJsonObject? latest;
    for (final message
        in projection?.messages.reversed ?? const <PiJsonObject>[]) {
      if (message['role'] == 'assistant' &&
          visibleText(message).trim().isNotEmpty) {
        latest = message;
        break;
      }
    }
    final text = projection?.streamingText?.trim().isNotEmpty == true
        ? projection!.streamingText!
        : latest == null
        ? ''
        : visibleText(latest);
    if (text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          'The latest Pi assistant response will appear here as Markdown.',
          style: tokens.control.copyWith(color: tokens.textSoft, height: 1.45),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            const Expanded(child: SectionLabel('Response preview')),
            IconButton(
              tooltip: 'Copy rendered Pi response source',
              visualDensity: VisualDensity.compact,
              onPressed: () => copyText(text),
              icon: const Icon(Icons.copy_outlined, size: 16),
            ),
          ],
        ),
        Text(
          projection?.isStreaming == true
              ? 'Streaming from Pi RPC'
              : 'Latest assistant message from Pi session',
          style: tokens.micro.copyWith(color: tokens.textFaint),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.bg,
            borderRadius: BorderRadius.circular(tokens.chipRadius),
            border: Border.all(color: tokens.line),
          ),
          child: MarkdownDocument(text: text, serif: true),
        ),
      ],
    );
  }
}

class _FlagRow extends StatelessWidget {
  const _FlagRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: tokens.control)),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _ForkRow extends StatelessWidget {
  const _ForkRow({
    required this.entryId,
    required this.text,
    required this.enabled,
    required this.onFork,
  });

  final String entryId;
  final String text;
  final bool enabled;
  final ValueChanged<String> onFork;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text.isEmpty ? entryId : text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: tokens.control.copyWith(height: 1.4),
            ),
          ),
          IconButton(
            tooltip: 'Fork from this Pi Entry',
            visualDensity: VisualDensity.compact,
            onPressed: enabled && entryId.isNotEmpty
                ? () => onFork(entryId)
                : null,
            icon: const Icon(Icons.call_split_outlined, size: 16),
          ),
        ],
      ),
    );
  }
}

class TreeItem {
  const TreeItem({
    required this.id,
    required this.parentId,
    required this.role,
    required this.label,
    required this.depth,
  });

  final String id;
  final String? parentId;
  final String role;
  final String? label;
  final int depth;
}

List<TreeItem> flattenTree(Object? value) {
  if (value is! List) {
    return const <TreeItem>[];
  }

  final result = <TreeItem>[];
  void visit(Object? rawNode, int depth) {
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
          TreeItem(
            id: id,
            parentId: entry['parentId'] as String?,
            role: message is Map && message['role'] is String
                ? message['role'] as String
                : entry['type'] as String? ?? 'entry',
            label: node['label'] as String?,
            depth: depth,
          ),
        );
      }
    }
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        visit(child, depth + 1);
      }
    }
  }

  for (final node in value) {
    visit(node, 0);
  }
  return result;
}
