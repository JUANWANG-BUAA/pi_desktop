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

Since M4 this scan is machine-enforced by
`test/boundary/boundary_scan_test.dart`, which fails the test suite when:

- a custom agent, harness or orchestration declaration appears (TODO.md §0.3);
- a Provider SDK import, Provider URL or desktop model registry appears (§8);
- a session database package or second conversation store appears (§9);
- a desktop-private plugin system or WebView dependency appears (§1.1 / §7);
- TUI ANSI capture or parsing appears (§0.3);
- a `lib/` file outside the reviewed allowlist imports `dart:io` (§0.2 / §9.2);
- an RPC command literal falls outside the official surface frozen in §3.2.

## Commit gate

`tool/check.sh` runs the four checks required by `docs/implementation-plan.md`
提交规则: `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`
(including the boundary scan) and `git diff --check`. `tool/install_hooks.sh`
installs it as the local pre-commit hook; git hooks are not pushed, so run it
once per clone.

## Deliberately pending checks

- Provider-dependent Prompt, Tool, Thinking, Compaction and Retry scenarios require a
  user-authenticated Pi Session. They are not run automatically to avoid consuming
  model quota or mutating a user Session.
- Windows and Linux native builds require the corresponding host or CI runner.
- Pi `0.84.2` RPC does not expose one unified resource-diagnostics command for all
  Extension, Skill, Prompt and Theme resources, and does not expose a session
  listing command. To render the Archive/Inspector the client performs two
  read-only filesystem operations: it lists Pi's session directory and reads
  the first bytes of each Session JSONL for a title preview
  (`lib/src/ui/pi_session_catalog.dart`), and it inventories
  `~/.pi/agent` skill/extension metadata (`lib/src/ui/pi_resource_catalog.dart`).
  Neither writes, copies, nor parses full session content, and switching still
  happens only through `switch_session`. This is a documented deviation from
  the strictest reading of "不直接读写 Session JSONL / 不扫描私有目录" and stays
  open pending an official Pi RPC for session listing and resource diagnostics.
- File attachments are sent as Pi-readable `@path` references composed into the
  prompt text (`prompt_bar.dart`). The added framing text is desktop-authored;
  it is visible in the composer and not hidden, but it is not an official Pi
  ImageContent path. Treat it as an open contract question for a future Pi RPC.
- Packaging a verified Pi runtime, signing, upgrade and uninstall checks belong to M5.

## Manual launch

For a local macOS preview:

```bash
flutter run -d macos
```

The desktop app starts the official Pi RPC process and restores the current Pi session;
without a working Pi executable or Pi configuration it remains a disconnected UI shell.
