import 'package:flutter/material.dart';

void main() {
  runApp(const PiDesktopApp());
}

class PiDesktopApp extends StatelessWidget {
  const PiDesktopApp({super.key});

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
      home: const DesktopShell(),
    );
  }
}

class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _ContextBar(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showInspector = constraints.maxWidth >= 980;
                  return Row(
                    children: [
                      const SizedBox(width: 260, child: _ArchivePane()),
                      const VerticalDivider(width: 1),
                      const Expanded(child: _TranscriptPane()),
                      if (showInspector) ...[
                        const VerticalDivider(width: 1),
                        const SizedBox(width: 280, child: _InspectorPane()),
                      ],
                    ],
                  );
                },
              ),
            ),
            const _PromptBar(),
          ],
        ),
      ),
    );
  }
}

class _ContextBar extends StatelessWidget {
  const _ContextBar();

  @override
  Widget build(BuildContext context) {
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
          const _ContextValue(label: 'cwd', value: '—'),
          const SizedBox(width: 20),
          const _ContextValue(label: 'session', value: 'not loaded'),
          const Spacer(),
          _StatusLabel(
            icon: Icons.link_off_outlined,
            label: 'Pi RPC disconnected',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  const _ArchivePane();

  @override
  Widget build(BuildContext context) {
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
          Text(
            'No working directory',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          Text(
            'RECENT SESSIONS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pi will provide Session entries here.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptPane extends StatelessWidget {
  const _TranscriptPane();

  @override
  Widget build(BuildContext context) {
    return _Pane(
      title: 'Transcript',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                size: 34,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 18),
              Text(
                'No Pi Session loaded',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'The transcript will be restored from Pi through the official RPC connection.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InspectorPane extends StatelessWidget {
  const _InspectorPane();

  @override
  Widget build(BuildContext context) {
    return _Pane(
      title: 'Inspector',
      child: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: const [
          _InspectorSection(title: 'Branch', value: 'Unavailable'),
          _InspectorSection(title: 'Tool', value: 'Unavailable'),
          _InspectorSection(title: 'Usage', value: 'Unavailable'),
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

class _PromptBar extends StatelessWidget {
  const _PromptBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Prompt will be sent through Pi RPC',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Pi RPC is not connected',
            child: IconButton(
              onPressed: null,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ),
        ],
      ),
    );
  }
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
