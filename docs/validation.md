# Validation Record

## Current baseline

- Flutter: 3.47.0
- Dart: 3.13.0
- Node.js: 24.19.0
- Pi: 0.84.2
- RPC mode: `pi --mode rpc`
- Session format: v3

## Local checks

The following checks pass on the current macOS development host:

```text
 dart format --output=none --set-exit-if-changed lib test
 flutter analyze --no-pub
 flutter test --no-pub
 flutter build macos --debug
 git diff --check
```

The test suite covers:

- LF/CRLF JSONL framing and UTF-8 split chunks;
- asynchronous Pi Events interleaved with Responses;
- concurrent response correlation;
- stderr isolation and process-exit rejection;
- official `extension_ui_response` framing;
- authoritative projection restore and Pi event projection;
- Tool, queue, compaction timeline, extension error and transient-state reset;
- official Pi RPC smoke and connection restore when Pi is installed.

## Boundary scan

The application source and tests contain no desktop Agent loop, custom Provider gateway,
second Session store, custom Tool scheduler, automatic follow-up/retry orchestration,
TUI ANSI capture, WebView, Electron or Tauri WebView implementation.

## Deliberately pending checks

- Provider-dependent Prompt, Tool, Thinking, Compaction and Retry scenarios require a
  user-authenticated Pi Session. They are not run automatically to avoid consuming
  model quota or mutating a user Session.
- Windows and Linux native builds require the corresponding host or CI runner.
- Pi `0.84.2` RPC does not expose one unified resource-diagnostics command for all
  Extension, Skill, Prompt and Theme resources. The client shows `get_commands`
  source/path data and does not scan or copy Pi private resource directories.
- Packaging a verified Pi runtime, signing, upgrade and uninstall checks belong to M5.

## Manual launch

For a local macOS preview:

```bash
flutter run -d macos
```

The desktop app starts the official Pi RPC process and restores the current Pi session;
without a working Pi executable or Pi configuration it remains a disconnected UI shell.
