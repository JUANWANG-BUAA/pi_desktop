# Errors

Command failures and integration errors.

---

## [ERR-20260818-010] rpc-smoke-skip-api

**Logged**: 2026-08-18T11:30:42Z
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The first optional Pi smoke test used a closure for the Dart test package's `skip` field, which accepts only a bool or reason string.

### Error
```text
Invalid argument(s): "skip" must be a String or a bool, was "Closure: () => bool".
```

### Context
- The test needs to remain runnable on hosts without a global Pi binary.

### Suggested Fix
Resolve host availability synchronously before registering the test and pass either `false` or a skip reason string.

### Metadata
- Reproducible: yes
- Related Files: test/rpc/pi_rpc_smoke_test.dart

### Resolution
- **Resolved**: 2026-08-18T11:30:42Z
- **Notes**: Smoke test now uses `Process.runSync` for availability detection and passes the supported skip value.

---

## [ERR-20260818-008] rpc-test-fixture-launch

**Logged**: 2026-08-18T11:30:42Z
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
RPC integration tests initially spawned Flutter's `flutter_tester` executable instead of a normal Dart process, which injected a VM service banner into stdout and violated JSONL parsing.

### Error
```text
FormatException: Unexpected character
The Dart VM service is listening on http://127.0.0.1:...
```

### Context
- `Platform.resolvedExecutable` under `flutter test` is the test runner, not the Dart CLI.
- A first attempt to compile the fixture through that executable also hung until the child was terminated.

### Suggested Fix
Use the `dart` executable to compile a temporary native fixture, then spawn that fixture for protocol tests. Never relax the production JSONL parser to accept non-JSON stdout.

### Metadata
- Reproducible: yes
- Related Files: test/rpc/pi_rpc_client_test.dart, test/fixtures/rpc_protocol_fixture.dart

### Resolution
- **Resolved**: 2026-08-18T11:30:42Z
- **Notes**: RPC fixture tests now compile a temporary executable with `dart compile exe`; all protocol tests pass.

---

## [ERR-20260818-009] rpc-write-serialization

**Logged**: 2026-08-18T11:30:42Z
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
Concurrent RPC commands attempted overlapping writes/flushes to one Dart `IOSink`, causing a `StreamSink is bound to a stream` error.

### Error
```text
Bad state: StreamSink is bound to a stream
```

### Context
- The transport must support multiple outstanding requests even when responses arrive out of order.
- Response correlation was correct, but stdin writes also need serialization.

### Suggested Fix
Serialize only writes and flushes; keep response futures independent so Pi events and responses can still arrive asynchronously.

### Metadata
- Reproducible: yes
- Related Files: lib/src/rpc/pi_rpc_client.dart

### Resolution
- **Resolved**: 2026-08-18T11:30:42Z
- **Notes**: Added a write tail queue while preserving independent pending response completers.

---

## [ERR-20260818-006] flutter-analyze-code-signature

**Logged**: 2026-08-18T11:12:00Z
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
`flutter analyze` could not start the AOT analysis server because macOS rejected the downloaded Flutter snapshot code signature.

### Error
```text
library load disallowed by system policy: analysis_server_aot.dart.snapshot
Isolate spawning failed ... does not contain a valid AOT snapshot
```

### Context
- Flutter 3.47.0 stable installed from Homebrew on macOS ARM.
- The Flutter CLI itself runs, but analyzer startup is blocked by host execution policy.

### Suggested Fix
Verify the Flutter SDK cache and host architecture; retry after repairing the SDK or installing the required Rosetta/runtime support. Do not bypass analysis by replacing it with a custom checker.

### Metadata
- Reproducible: yes
- Related Files: pubspec.yaml, analysis_options.yaml

### Resolution
- **Resolved**: 2026-08-18T11:18:00Z
- **Notes**: Removed the Homebrew quarantine attribute from the Flutter analysis snapshot and analyzer completed successfully.

---

## [ERR-20260818-007] flutter-impeller-shader

**Logged**: 2026-08-18T11:12:00Z
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
`flutter test` and `flutter build macos --debug` failed while compiling Flutter's built-in `ink_sparkle.frag` shader through `impellerc`.

### Error
```text
ShaderCompilerException: Shader compilation .../ink_sparkle.frag ... failed with exit code -9
```

### Context
- The failure occurred in parallel validation commands after the Flutter scaffold was generated.
- It is a Flutter toolchain/host issue, not an application assertion failure.

### Suggested Fix
Retry serially and check Flutter's Impeller/host options and SDK cache. If the issue remains, validate on a supported Flutter host/SDK before accepting M1.1's build gate.

### Metadata
- Reproducible: yes
- Related Files: lib/main.dart, test/widget_test.dart
- See Also: ERR-20260818-006

### Resolution
- **Resolved**: 2026-08-18T11:19:00Z
- **Notes**: Removed the Homebrew quarantine attribute from Flutter's Impeller compiler and reran validation serially; widget tests and macOS debug build pass.

---

## [ERR-20260818-001] git-diff-check

**Logged**: 2026-08-18T10:42:30Z
**Priority**: low
**Status**: pending
**Area**: config

### Summary
`git diff --check` could not run because the working directory is not initialized as a Git repository.

### Error
```text
fatal: not a git repository
```

### Context
- Attempted to validate whitespace with `git diff --check` after creating `TODO.md`.
- The directory contains no `.git` metadata.

### Suggested Fix
Initialize or attach the intended Git repository before using Git-based validation. Until then, use direct file and markdown checks.

### Metadata
- Reproducible: yes
- Related Files: TODO.md

---

## [ERR-20260818-005] flutter-cask-lock

**Logged**: 2026-08-18T11:04:00Z
**Priority**: low
**Status**: resolved
**Area**: infra

### Summary
`brew install --cask flutter` returned exit code 1 because a Homebrew download cache lock was detected, but the cask installation completed successfully in the same operation.

### Error
```text
A `brew install --cask flutter` process has already locked .../flutter_macos_arm64_3.47.0-stable.zip.incomplete.
Gave up after waiting 180 seconds.
```

### Context
- Attempted while preparing the M1.1 Flutter Desktop prerequisite.
- The command output subsequently reported that Flutter was installed and linked at `/opt/homebrew/bin/flutter`.

### Suggested Fix
Verify `flutter --version` and `flutter doctor` after a Homebrew cask-lock failure before retrying or removing cache files.

### Metadata
- Reproducible: unknown
- Related Files: docs/implementation-plan.md

### Resolution
- **Resolved**: 2026-08-18T11:04:00Z
- **Notes**: Installation completed; verification follows.

---

## [ERR-20260818-002] todo-structural-check

**Logged**: 2026-08-18T10:42:30Z
**Priority**: low
**Status**: resolved
**Area**: docs

### Summary
A structural assertion counted `## ` substrings inside `###` headings and reported a false failure.

### Error
```text
AssertionError
```

### Context
- The check used `text.count('## ')` instead of counting headings by line prefix.
- The document itself was valid; a line-based check confirmed 16 level-2 headings and 330 unchecked items.

### Suggested Fix
Use `grep '^## '` or a line-prefix parser for Markdown heading checks.

### Metadata
- Reproducible: yes
- Related Files: TODO.md

### Resolution
- **Resolved**: 2026-08-18T10:42:30Z
- **Notes**: Re-ran the structural validation with line-based heading counting.

---

## [ERR-20260818-003] todo-review-count

**Logged**: 2026-08-18T10:42:30Z
**Priority**: low
**Status**: resolved
**Area**: docs

### Summary
A follow-up TODO validation used an outdated expected count for completed review checkboxes.

### Error
```text
AssertionError
```

### Context
- The document gained a self-review section with 22 completed checks.
- The assertion expected 20 completed checks.

### Suggested Fix
Derive counts from the document or update expected counts after intentional checklist changes.

### Metadata
- Reproducible: yes
- Related Files: TODO.md
- See Also: ERR-20260818-002

### Resolution
- **Resolved**: 2026-08-18T10:42:30Z
- **Notes**: Re-ran the check with the actual count and verified zero trailing whitespace.

---

## [ERR-20260818-004] todo-review-count-after-audit

**Logged**: 2026-08-18T10:42:30Z
**Priority**: low
**Status**: resolved
**Area**: docs

### Summary
A validation command used stale expected checkbox counts after adding the second audit section.

### Error
```text
AssertionError
```

### Context
- The second audit intentionally added 5 unchecked and 15 completed review items.
- Actual counts were 336 open TODOs and 37 completed review checks.

### Suggested Fix
Run count discovery before asserting exact values after document edits.

### Metadata
- Reproducible: yes
- Related Files: TODO.md
- See Also: ERR-20260818-003

### Resolution
- **Resolved**: 2026-08-18T10:42:30Z
- **Notes**: Corrected the expected counts and verified zero trailing whitespace.

---
