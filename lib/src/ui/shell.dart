import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../rpc/pi_rpc_client.dart';
import '../session/pi_desktop_connection.dart';
import '../session/pi_session_projection.dart';
import 'archive_pane.dart';
import 'context_bar.dart';
import 'inspector_pane.dart';
import 'listenables.dart';
import 'pi_tokens.dart';
import 'pi_session_catalog.dart';
import 'prompt_bar.dart';
import 'settings_dialog.dart';
import 'transcript_pane.dart';
import 'ui_preferences.dart';
import 'widgets.dart';
import 'workspace_io.dart';

class DesktopShell extends StatelessWidget {
  const DesktopShell({
    required this.connection,
    required this.preferences,
    this.enableRuntimeInspection = true,
    super.key,
  });

  final PiDesktopConnection connection;
  final UiPreferences preferences;
  final bool enableRuntimeInspection;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, child) => _ShellLayout(
        connection: connection,
        preferences: preferences,
        enableRuntimeInspection: enableRuntimeInspection,
      ),
    );
  }
}

class _ShellLayout extends StatefulWidget {
  const _ShellLayout({
    required this.connection,
    required this.preferences,
    required this.enableRuntimeInspection,
  });

  final PiDesktopConnection connection;
  final UiPreferences preferences;
  final bool enableRuntimeInspection;

  @override
  State<_ShellLayout> createState() => _ShellLayoutState();
}

class _ShellLayoutState extends State<_ShellLayout>
    with TickerProviderStateMixin {
  final _promptFocus = FocusNode(debugLabel: 'Pi prompt');

  /// Composer draft owned here so it survives landing/session layout swaps.
  /// Text drafts are additionally keyed per Pi session so switching sessions
  /// does not leak one session's half-typed prompt into another.
  final _draftController = TextEditingController();
  final Map<String, String> _sessionDrafts = <String, String>{};
  String? _draftSessionId;

  PiDesktopConnection get _connection => widget.connection;
  UiPreferences get _preferences => widget.preferences;

  @override
  void didUpdateWidget(covariant _ShellLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDraftSession();
  }

  void _syncDraftSession() {
    final sessionId = _connection.projection?.state?['sessionId'] as String?;
    if (sessionId == _draftSessionId) {
      return;
    }
    if (_draftSessionId != null) {
      _sessionDrafts[_draftSessionId!] = _draftController.text;
    }
    _draftSessionId = sessionId;
    final draft = sessionId == null ? null : _sessionDrafts[sessionId];
    if (draft != null && draft != _draftController.text) {
      _draftController.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    }
  }

  @override
  void dispose() {
    _promptFocus.dispose();
    _draftController.dispose();
    super.dispose();
  }

  Future<void> _showCommandPalette() async {
    final sessionActions = PiSessionCatalog(_connection.workingDirectory)
        .load()
        .then(
          (sessions) => [
            for (final session in sessions.take(8))
              _PaletteAction(
                'Open: ${session.title}',
                Icons.history,
                _connection.isConnected
                    ? () async {
                        await _switchSession(session.path);
                      }
                    : null,
              ),
          ],
        );
    final selected = await showDialog<_PaletteAction>(
      context: context,
      builder: (context) => _CommandPalette(
        actions: [
          _PaletteAction(
            'New Pi session',
            Icons.add,
            _connection.isConnected
                ? () async {
                    await _connection.newSession();
                  }
                : null,
          ),
          _PaletteAction(
            'Focus composer',
            Icons.edit_outlined,
            () async => _promptFocus.requestFocus(),
          ),
          _PaletteAction(
            'Choose workspace',
            Icons.folder_outlined,
            () => chooseWorkspace(
              connection: _connection,
              preferences: _preferences,
            ),
          ),
          _PaletteAction(
            'Toggle Pi details',
            Icons.view_sidebar_outlined,
            _preferences.toggleInspector,
          ),
          _PaletteAction(
            'Toggle display',
            Icons.contrast_outlined,
            _preferences.cycleThemeMode,
          ),
          _PaletteAction(
            'Open settings',
            Icons.settings_outlined,
            _showSettings,
          ),
        ],
        sessionActions: sessionActions,
      ),
    );
    if (selected != null) await selected.run?.call();
  }

  Future<void> _switchSession(String path) async {
    PiRpcResponse response;
    try {
      response = await _connection.switchSession(path);
    } on Object catch (error) {
      _notify('Pi session switch failed: $error');
      return;
    }
    if (response.cancelledByExtension) {
      _notify('A Pi extension cancelled the session switch.');
    } else if (!response.success) {
      _notify(response.error ?? 'Pi rejected switch_session.');
    }
  }

  void _notify(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSettings() {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          SettingsDialog(preferences: _preferences, connection: _connection),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.escape): const AbortIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            const NewSessionIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            const NewSessionIntent(),
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
            const FocusPromptIntent(),
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            const FocusPromptIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            const CommandPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const CommandPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyD, meta: true, shift: true):
            const ToggleThemeIntent(),
        const SingleActivator(
          LogicalKeyboardKey.keyD,
          control: true,
          shift: true,
        ): const ToggleThemeIntent(),
        const SingleActivator(LogicalKeyboardKey.keyJ, meta: true, shift: true):
            const ToggleDensityIntent(),
        const SingleActivator(
          LogicalKeyboardKey.keyJ,
          control: true,
          shift: true,
        ): const ToggleDensityIntent(),
        const SingleActivator(LogicalKeyboardKey.period, meta: true):
            const AbortIntent(),
        const SingleActivator(LogicalKeyboardKey.period, control: true):
            const AbortIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          AbortIntent: CallbackAction<AbortIntent>(
            onInvoke: (_) {
              if (_connection.isStreaming && _connection.isConnected) {
                unawaited(_connection.abort());
              }
              return null;
            },
          ),
          NewSessionIntent: CallbackAction<NewSessionIntent>(
            onInvoke: (_) {
              if (_connection.isConnected) {
                unawaited(_connection.newSession());
              }
              return null;
            },
          ),
          FocusPromptIntent: CallbackAction<FocusPromptIntent>(
            onInvoke: (_) {
              _promptFocus.requestFocus();
              return null;
            },
          ),
          CommandPaletteIntent: CallbackAction<CommandPaletteIntent>(
            onInvoke: (_) {
              unawaited(_showCommandPalette());
              return null;
            },
          ),
          ToggleThemeIntent: CallbackAction<ToggleThemeIntent>(
            onInvoke: (_) {
              unawaited(_preferences.cycleThemeMode());
              return null;
            },
          ),
          ToggleDensityIntent: CallbackAction<ToggleDensityIntent>(
            onInvoke: (_) {
              unawaited(_preferences.cycleDensity());
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: tokens.bg,
            body: LayoutBuilder(
              builder: (context, constraints) {
                final showArchive =
                    _preferences.archiveVisible && constraints.maxWidth >= 720;
                final showInspector =
                    _preferences.inspectorVisible &&
                    constraints.maxWidth >= (showArchive ? 1040 : 780);
                return Row(
                  children: [
                    _AnimatedSidePane(
                      visible: showArchive,
                      width: _preferences.archiveWidth + 8,
                      child: Row(
                        children: [
                          SizedBox(
                            width: _preferences.archiveWidth,
                            child: BoundConnection(
                              connection: _connection,
                              select: (connection, projection) =>
                                  '${connection.status}|${projection?.chromeEpoch}|${projection?.state?['sessionId']}|${connection.errorMessage}',
                              builder: (context, connection, projection) =>
                                  ArchivePane(
                                    connection: connection,
                                    preferences: _preferences,
                                    workspacePath: connection.workingDirectory,
                                    currentSessionId:
                                        projection?.state?['sessionId']
                                            as String?,
                                    enableRuntimeInspection:
                                        widget.enableRuntimeInspection,
                                  ),
                            ),
                          ),
                          ResizeHandle(
                            onDrag: (delta) => _preferences.setArchiveWidth(
                              _preferences.archiveWidth + delta,
                            ),
                            onDragEnd: _preferences.persistLayout,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          // Keep the quiet Claude-like motion present after a
                          // session begins as well. It is deliberately below
                          // every interactive surface and repaint-isolated.
                          const Positioned.fill(
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: 0.48,
                                child: _DotField(intensity: 0.72, spacing: 12),
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              const SizedBox(height: 28),
                              BoundConnection(
                                connection: _connection,
                                select: (connection, projection) =>
                                    '${connection.status}|${projection?.chromeEpoch}|${connection.extensionTitle}|${connection.errorMessage}|${connection.isStreaming}',
                                builder: (context, connection, projection) =>
                                    ContextBar(
                                      connection: connection,
                                      preferences: _preferences,
                                      archiveTemporarilyHidden:
                                          _preferences.archiveVisible &&
                                          !showArchive,
                                      inspectorTemporarilyHidden:
                                          _preferences.inspectorVisible &&
                                          !showInspector,
                                      onOpenSettings: _showSettings,
                                      onToggleInspector: () => unawaited(
                                        _preferences.toggleInspector(),
                                      ),
                                    ),
                              ),
                              Expanded(
                                child: BoundConnection(
                                  connection: _connection,
                                  select: (connection, projection) =>
                                      '${connection.status}|${projection?.structureEpoch}|${projection?.chromeEpoch}|${projection?.isStreaming}|${connection.extensionEditorText}|${connection.extensionStatuses.length}',
                                  builder: (context, connection, projection) {
                                    final landing = _isLanding(projection);
                                    if (landing) {
                                      return _LandingWorkspace(
                                        connection: connection,
                                        preferences: _preferences,
                                        promptFocus: _promptFocus,
                                        draftController: _draftController,
                                      );
                                    }
                                    return Column(
                                      children: [
                                        Expanded(
                                          child: TranscriptPane(
                                            connection: connection,
                                            projection: projection,
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.bottomCenter,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 760,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                  ),
                                              child: PromptBar(
                                                connection: connection,
                                                preferences: _preferences,
                                                focusNode: _promptFocus,
                                                draftController:
                                                    _draftController,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _AnimatedSidePane(
                      visible: showInspector,
                      width: _preferences.inspectorWidth + 8,
                      child: Row(
                        children: [
                          ResizeHandle(
                            onDrag: (delta) => _preferences.setInspectorWidth(
                              _preferences.inspectorWidth - delta,
                            ),
                            onDragEnd: _preferences.persistLayout,
                          ),
                          SizedBox(
                            width: _preferences.inspectorWidth,
                            child: BoundConnection(
                              connection: _connection,
                              select: (connection, projection) =>
                                  '${connection.status}|${projection?.chromeEpoch}|${projection?.structureEpoch}|${connection.extensionStatuses.length}',
                              builder: (context, connection, projection) =>
                                  InspectorPane(connection: connection),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedSidePane extends StatelessWidget {
  const _AnimatedSidePane({
    required this.visible,
    required this.width,
    required this.child,
  });

  final bool visible;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Flex must receive the final width in the same layout pass; animating it
    // here can allocate the center pane using stale constraints. Animate only
    // the pane content, while its layout slot changes atomically.
    if (!visible) return const SizedBox.shrink();
    return SizedBox(
      width: width,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((1 - value) * 10, 0),
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }
}

bool _isLanding(PiSessionProjection? projection) {
  if (projection == null) {
    return true;
  }
  return projection.messages.isEmpty &&
      !projection.isStreaming &&
      projection.toolEvents.isEmpty;
}

class _LandingWorkspace extends StatefulWidget {
  const _LandingWorkspace({
    required this.connection,
    required this.preferences,
    required this.promptFocus,
    required this.draftController,
  });

  final PiDesktopConnection connection;
  final UiPreferences preferences;
  final FocusNode promptFocus;
  final TextEditingController draftController;

  @override
  State<_LandingWorkspace> createState() => _LandingWorkspaceState();
}

class _LandingWorkspaceState extends State<_LandingWorkspace> {
  var _sending = false;

  PiDesktopConnection get connection => widget.connection;
  UiPreferences get preferences => widget.preferences;
  FocusNode get promptFocus => widget.promptFocus;
  TextEditingController get draftController => widget.draftController;

  Future<void> _startTask(String prompt) async {
    if (_sending || connection.isStreaming) {
      return;
    }
    setState(() => _sending = true);
    try {
      final response = await connection.prompt(prompt);
      if (!response.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.error ?? 'Pi rejected the prompt.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Pi prompt failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final connected = connection.isConnected;
    return Stack(
      children: [
        const Positioned.fill(child: IgnorePointer(child: _DotField())),
        Align(
          alignment: connected ? Alignment.topCenter : Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              // The connected workspace mirrors a desktop work surface: the
              // invitation starts above the visual midpoint, leaving room for
              // the task shortcuts below it. An unavailable runtime remains
              // centered so its recovery action is immediately discoverable.
              padding: EdgeInsets.fromLTRB(32, connected ? 22 : 12, 32, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 19, color: tokens.accent),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          connected
                              ? 'What can Pi take off your plate?'
                              : 'Connect Pi to begin',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.display.copyWith(fontSize: 29),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    connected
                        ? 'Work directly with the current project and Pi session.'
                        : 'Pi Desktop connects directly to the official Pi RPC process.',
                    style: tokens.control.copyWith(
                      color: tokens.textSoft,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  PromptBar(
                    connection: connection,
                    preferences: preferences,
                    focusNode: promptFocus,
                    landing: true,
                    draftController: draftController,
                  ),
                  if (connected) ...[
                    // Keep the invitation and composer high on the page, then
                    // give the task rail its own calm visual section.
                    const SizedBox(height: 110),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Start with a task', style: tokens.micro),
                    ),
                    const SizedBox(height: 8),
                    _LandingTask(
                      icon: Icons.account_tree_outlined,
                      label: 'Understand this project',
                      busy: _sending,
                      onTap: () => unawaited(
                        _startTask('Please help me understand this project.'),
                      ),
                    ),
                    _LandingTask(
                      icon: Icons.manage_search_outlined,
                      label: 'Find insights in files',
                      busy: _sending,
                      onTap: () => unawaited(
                        _startTask(
                          'Please inspect the project files and surface useful insights.',
                        ),
                      ),
                    ),
                    _LandingTask(
                      icon: Icons.edit_note_outlined,
                      label: 'Plan a change',
                      busy: _sending,
                      onTap: () => unawaited(
                        _startTask('Help me plan a change for this project.'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LandingTask extends StatelessWidget {
  const _LandingTask({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 18, color: tokens.textFaint),
              const SizedBox(width: 10),
              Text(
                label,
                style: tokens.control.copyWith(color: tokens.textSoft),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: tokens.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotField extends StatefulWidget {
  const _DotField({this.intensity = 1, this.spacing = 9});

  final double intensity;
  final double spacing;

  @override
  State<_DotField> createState() => _DotFieldState();
}

class _DotFieldState extends State<_DotField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _DotFieldPainter(
          color: tokens.line.withValues(alpha: 0.5 * widget.intensity),
          spacing: widget.spacing,
          phase: reduceMotion ? 0 : _drift.value,
          repaint: reduceMotion ? null : _drift,
        ),
      ),
    );
  }
}

class _DotFieldPainter extends CustomPainter {
  const _DotFieldPainter({
    required this.color,
    required this.spacing,
    required this.phase,
    super.repaint,
  });

  final Color color;
  final double spacing;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = 0.82 + 0.18 * math.sin(phase * math.pi * 2);
    final paint = Paint()..color = color.withValues(alpha: color.a * pulse);
    final bounds = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.57),
      width: 540,
      height: 500,
    );
    final drift = Offset(
      math.sin(phase * math.pi * 2) * 9,
      math.cos(phase * math.pi * 2) * 5,
    );
    canvas.save();
    canvas.clipRect(bounds);
    for (
      var x = bounds.left - spacing + drift.dx;
      x < bounds.right + spacing;
      x += spacing
    ) {
      for (
        var y = bounds.top - spacing + drift.dy;
        y < bounds.bottom + spacing;
        y += spacing
      ) {
        canvas.drawCircle(Offset(x, y), 0.65, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DotFieldPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.spacing != spacing ||
      oldDelegate.phase != phase;
}

class AbortIntent extends Intent {
  const AbortIntent();
}

class NewSessionIntent extends Intent {
  const NewSessionIntent();
}

class FocusPromptIntent extends Intent {
  const FocusPromptIntent();
}

class ToggleThemeIntent extends Intent {
  const ToggleThemeIntent();
}

class ToggleDensityIntent extends Intent {
  const ToggleDensityIntent();
}

class CommandPaletteIntent extends Intent {
  const CommandPaletteIntent();
}

class _PaletteAction {
  const _PaletteAction(this.label, this.icon, this.run);

  final String label;
  final IconData icon;
  final Future<void> Function()? run;
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({required this.actions, required this.sessionActions});
  final List<_PaletteAction> actions;
  final Future<List<_PaletteAction>> sessionActions;

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  var _query = '';
  var _loadingSessions = true;
  var _couldNotLoadSessions = false;
  List<_PaletteAction> _sessionActions = const [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final actions = await widget.sessionActions;
      if (!mounted) return;
      setState(() {
        _loadingSessions = false;
        _sessionActions = actions;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSessions = false;
        _couldNotLoadSessions = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = [...widget.actions, ..._sessionActions]
        .where(
          (item) =>
              _query.trim().isEmpty ||
              item.label.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList(growable: false);
    return AlertDialog(
      title: const Text('Command palette'),
      content: SizedBox(
        width: 520,
        height: 390,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              onSubmitted: (_) {
                final runnable = visible
                    .where((item) => item.run != null)
                    .toList(growable: false);
                if (runnable.length == 1) {
                  Navigator.pop(context, runnable.single);
                }
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search Pi actions and sessions',
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final item in visible)
                    ListTile(
                      leading: Icon(item.icon, size: 18),
                      title: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      enabled: item.run != null,
                      onTap: item.run == null
                          ? null
                          : () => Navigator.pop(context, item),
                    ),
                  if (visible.isEmpty && !_loadingSessions)
                    const ListTile(
                      leading: Icon(Icons.search_off_outlined, size: 18),
                      title: Text('No matching Pi action or session'),
                    ),
                  if (_loadingSessions)
                    const ListTile(
                      leading: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      title: Text('Loading recent Pi sessions…'),
                    ),
                  if (_couldNotLoadSessions)
                    const ListTile(
                      leading: Icon(Icons.info_outline, size: 18),
                      title: Text('Recent Pi sessions are unavailable'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
