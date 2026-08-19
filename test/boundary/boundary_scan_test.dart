import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Machine-enforced boundary contract for Pi Desktop.
///
/// The frozen contract (TODO.md sections 0.3, 3.2, 11.4 and
/// docs/architecture.md) says the desktop app is only a thin Pi RPC client
/// plus a display layer. These scans fail the test suite as soon as a second
/// agent layer, provider gateway, session store, plugin platform, or TUI
/// ANSI capture appears in the Dart sources, instead of relying on manual
/// review alone. The self-scan excludes this file because it must name the
/// forbidden identifiers to detect them.
void main() {
  final sources = _loadSources();

  group('boundary contract (TODO.md §0.3 / §11.4)', () {
    test('sources exist to scan', () {
      expect(sources, isNotEmpty);
    });

    test('no custom agent, harness or orchestration layer', () {
      _expectAbsent(
        sources,
        <RegExp>[
          RegExp(
            r'\b(class|mixin|enum|extension|typedef)\s+'
            r'(AppAgent|TaskRunner|WorkflowEngine|MemoryManager|AgentLoop|'
            r'AgentHost|AgentService|AgentScheduler|PlanRunner|PromptInjector)',
          ),
          RegExp(
            r'\b(runTask|startAgent|askAndSummarize|autoContinue|createPlan|'
            r'smartRetry|autoFollowUp|autoSteer)\s*\(',
          ),
        ],
        hint:
            'TODO.md §0.3 forbids desktop-side agent orchestration; '
            'all agent behavior must come from Pi RPC.',
      );
    });

    test('no direct provider gateway or model routing', () {
      _expectAbsent(
        sources,
        <RegExp>[
          RegExp(
            r"import\s+'package:(openai|anthropic|google_generative_ai|"
            r'langchain|vertex_ai|ollama|groq)/',
          ),
          RegExp(
            r'https?://(api\.openai\.com|api\.anthropic\.com|'
            r'generativelanguage\.googleapis\.com)',
          ),
          RegExp(
            r'\b(class|mixin)\s+\w*(ProviderGateway|ModelRouter|'
            r'ModelRegistry|CredentialModel)\w*\b',
          ),
        ],
        hint:
            'TODO.md §8 forbids calling providers directly or building a '
            'desktop model registry; models and auth belong to Pi.',
      );
    });

    test('no second conversation/session store', () {
      _expectAbsent(
        sources,
        <RegExp>[
          RegExp(
            r"import\s+'package:(sqflite|sqlite3|drift|hive|isar|"
            r'realm|objectbox)/',
          ),
          RegExp(
            r'\b(class|mixin)\s+\w*(ConversationStore|SessionDatabase|'
            r'SessionStore|MessageDatabase)\w*\b',
          ),
        ],
        hint:
            'TODO.md §9 forbids copying Pi sessions into a desktop '
            'database; Pi Session JSONL is the only source of truth.',
      );
    });

    test('no desktop-private plugin system or webview UI', () {
      _expectAbsent(
        sources,
        <RegExp>[
          RegExp(
            r"import\s+'package:(webview_flutter|flutter_inappwebview|"
            r'desktop_webview|url_launcher)/',
          ),
          RegExp(
            r'\b(class|mixin)\s+\w*(PluginMarket|DesktopPlugin|'
            r'PluginRegistry|PluginSandbox)\w*\b',
          ),
        ],
        hint:
            'TODO.md §1.1 / §7 forbid WebView UI and desktop plugin '
            'platforms; user extensions stay Pi Packages.',
      );
    });

    test('no TUI ANSI capture or parsing', () {
      _expectAbsent(
        sources,
        <RegExp>[
          // ANSI CSI escape parsing would mean the GUI consumes TUI output.
          RegExp(r'\\x1[Bb]\[|\\u001[Bb]\[|\x1B\['),
          RegExp(r"import\s+'package:ansi/"),
        ],
        hint:
            'TODO.md §0.3 forbids scraping TUI ANSI output; the GUI only '
            'consumes the Pi JSONL protocol.',
      );
    });

    test('dart:io stays within the process/filesystem edge', () {
      // dart:io is the only edge that could reach sockets or the filesystem.
      // Keep it on an explicit allowlist so production code cannot grow
      // direct network calls or private file access without a boundary
      // review. Test code is exempt because it needs file/process fixtures.
      const allowed = <String>{
        'lib/src/rpc/pi_rpc_client.dart', // spawns the official Pi subprocess
        'lib/src/session/pi_desktop_connection.dart', // launch dir, stderr
        'lib/src/session/pi_installation.dart', // explicit Pi CLI setup
        'lib/src/session/pi_baseline.dart', // version gate for spawned Pi
        'lib/src/ui/ui_preferences.dart', // pure UI preferences persistence
        'lib/src/ui/workspace_io.dart', // workspace path helpers
        'lib/src/ui/workspace_file_catalog.dart', // workspace file listing
        'lib/src/ui/pi_session_catalog.dart', // read-only Pi session listing
        'lib/src/ui/pi_resource_catalog.dart', // read-only resource listing
      };
      for (final entry in sources.entries) {
        if (!entry.key.startsWith('lib/')) {
          continue;
        }
        if (!entry.value.contains("import 'dart:io'")) {
          continue;
        }
        expect(
          allowed,
          contains(entry.key),
          reason:
              '${entry.key} imports dart:io, which is only allowed for '
              'the Pi subprocess edge, read-only Pi/workspace listings, and '
              'pure UI preferences (TODO.md §0.2 / §9.2).',
        );
      }
    });

    test('no desktop private RPC command surface', () {
      // sendCommand / _send / _sessionCommand are the only funnels into Pi
      // RPC. Every literal command name must belong to the official Pi RPC
      // surface frozen in TODO.md §3.2.
      const official = <String>{
        'prompt',
        'steer',
        'follow_up',
        'abort',
        'get_state',
        'get_messages',
        'get_entries',
        'get_tree',
        'new_session',
        'switch_session',
        'fork',
        'clone',
        'set_model',
        'cycle_model',
        'get_available_models',
        'set_thinking_level',
        'cycle_thinking_level',
        'get_available_thinking_levels',
        'set_steering_mode',
        'set_follow_up_mode',
        'compact',
        'set_auto_compaction',
        'set_auto_retry',
        'abort_retry',
        'get_session_stats',
        'get_fork_messages',
        'get_last_assistant_text',
        'set_session_name',
        'get_commands',
        'export_html',
        'extension_ui_response',
      };
      final sendCall = RegExp(
        r"(?:sendCommand|_send|_sessionCommand)\(\s*'([^']+)'",
      );
      final used = <String>{};
      for (final entry in sources.entries) {
        if (!entry.key.startsWith('lib/')) {
          // Test fixtures speak their own control protocol (emit_event,
          // event_then_response, ...); the contract binds the app itself.
          continue;
        }
        for (final match in sendCall.allMatches(entry.value)) {
          used.add(match.group(1)!);
        }
      }
      expect(
        used,
        isNotEmpty,
        reason: 'expected at least one Pi RPC call in the client.',
      );
      for (final command in used) {
        expect(
          official,
          contains(command),
          reason:
              "'$command' is not part of the official Pi RPC surface "
              'frozen in TODO.md §3.2.',
        );
      }
    });
  });
}

Map<String, String> _loadSources() {
  final root = Directory.current.path;
  final self = 'test/boundary/boundary_scan_test.dart';
  final sources = <String, String>{};
  for (final dirName in const <String>['lib', 'test']) {
    final dir = Directory('$root/$dirName');
    if (!dir.existsSync()) {
      continue;
    }
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final relative = entity.path
          .replaceFirst('$root/', '')
          .replaceAll(r'\', '/');
      if (relative == self) {
        continue;
      }
      sources[relative] = entity.readAsStringSync();
    }
  }
  return sources;
}

void _expectAbsent(
  Map<String, String> sources,
  List<RegExp> patterns, {
  required String hint,
}) {
  final hits = <String>[];
  for (final entry in sources.entries) {
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(entry.value)) {
        final line = entry.value.substring(0, match.start).split('\n').length;
        hits.add('${entry.key}:$line -> ${match.group(0)}');
      }
    }
  }
  expect(hits, isEmpty, reason: '${hits.join('\n')}\n$hint');
}
