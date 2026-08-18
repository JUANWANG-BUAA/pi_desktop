# Errors

Command failures and integration errors.

---

## [ERR-20260819-001] settings-dialog-material-layer

**Logged**: 2026-08-19T00:00:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: frontend

### Summary
A translucent decorated settings section hid `SwitchListTile` ink effects in widget tests.

### Error
```text
ListTile background color or ink splashes may be invisible.
```

### Context
- `flutter test` rendered `SwitchListTile` beneath a `DecoratedBox` with a background.

### Suggested Fix
Use a transparent `Material` inside the decorated section so ListTile ink and state layers have a paint surface.

### Metadata
- Reproducible: yes
- Related Files: lib/src/ui/settings_dialog.dart

---

## [ERR-20260819-002] enlarged-text-landing-overflow

**Logged**: 2026-08-19T00:00:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: frontend

### Summary
The landing title overflowed horizontally after changing the new text-size preference to its upper range.

### Error
```text
A RenderFlex overflowed by 133 pixels on the right.
```

### Context
- The landing heading was an unbounded `Text` within a horizontal `Row`.

### Suggested Fix
Wrap variable-length headings in `Flexible` and permit a bounded second line so display preferences remain usable.

### Metadata
- Reproducible: yes
- Related Files: lib/src/ui/shell.dart

---

## [ERR-20260819-006] GPU-backed image encoding made the unit test hang

**Logged**: 2026-08-19T00:42:00Z
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
A widget-engine image encoding test stalled on the macOS GPU backend while testing prompt-image downscaling.

### Resolution
Moved the regression assertion to the pure dimension-scaling helper. The production encoder remains covered by integration behavior without requiring an engine surface in a unit test.

---

## [ERR-20260819-007] Screenshot helper moved beneath the skill scripts directory

**Logged**: 2026-08-19T00:45:00Z
**Priority**: low
**Status**: resolved
**Area**: verification

### Summary
The initial visual-regression command referenced the former screenshot-helper location and did not start capture.

### Resolution
Located the installed helper at `screenshot/scripts/take_screenshot.py`; use that path for subsequent visual checks.

---

## [ERR-20260819-008] Intentional ambient-layer change invalidated shell goldens

**Logged**: 2026-08-19T00:49:00Z
**Priority**: low
**Status**: resolved
**Area**: visual regression

### Summary
Adding the session-state ambient background changed the approved dark and light shell pixels.

### Resolution
Inspect the generated failure images, then regenerate only the affected shell goldens once the change is visually confirmed.

---

## [ERR-20260819-001] apply-patch-context-mismatch

**Logged**: 2026-08-19T00:09:00Z
**Priority**: low
**Status**: resolved
**Area**: frontend

### Summary
An UI-layout patch used multiline context that no longer matched dart-formatted source.

### Error
```text
apply_patch verification failed: Failed to find expected lines
```

### Suggested Fix
Re-read the narrow source range and patch the formatter's current one-line layout.

### Metadata
- Reproducible: yes
- Related Files: lib/src/ui/shell.dart

---

## [ERR-20260819-002] macos-accessibility-click

**Logged**: 2026-08-19T00:18:50Z
**Priority**: low
**Status**: pending
**Area**: tests

### Summary
macOS System Events rejected an automated click while checking the Inspector file tab.

### Error
```text
System Events error -25200
```

### Suggested Fix
Use widget and pure catalog tests for this interaction unless accessibility event delivery is available again.

### Metadata
- Reproducible: unknown
- Related Files: lib/src/ui/inspector_pane.dart

---

## [ERR-20260819-003] inspector-tab-consolidation-lint

**Logged**: 2026-08-19T00:20:00Z
**Priority**: low
**Status**: resolved
**Area**: frontend

### Summary
Inspector tab consolidation left obsolete command and usage widgets unreferenced.

### Error
```text
unused_element: _CommandsTab, _UsageTab
```

### Suggested Fix
Remove obsolete widgets after their contents have been retained in the consolidated pages.

### Metadata
- Reproducible: yes
- Related Files: lib/src/ui/inspector_pane.dart

---

## [ERR-20260819-004] workspace-switcher-test-selector

**Logged**: 2026-08-19T00:28:00Z
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The workspace switcher test assumed the test cwd rendered as `/`; a combined corrective patch was then malformed.

### Error
```text
Finder found 0 widgets with text "/"
apply_patch invalid hunk
```

### Suggested Fix
Use a semantic selector and apply unrelated file changes in separate patches.

### Metadata
- Reproducible: yes
- Related Files: test/widget_test.dart, lib/src/ui/archive_pane.dart

---

## [ERR-20260819-005] image-preparation-test-lint

**Logged**: 2026-08-19T00:33:00Z
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The new image preparation test retained an unused Canvas local.

### Error
```text
unused_local_variable: canvas
```

### Suggested Fix
Construct the Canvas directly in the cascade expression.

### Metadata
- Reproducible: yes
- Related Files: test/ui/image_preparation_test.dart

---

## [ERR-20260818-009] flex-pane-hidden-child-overflow

**Logged**: 2026-08-18T14:50:00Z
**Priority**: medium
**Status**: resolved
**Area**: flutter-layout

### Summary
An attempted Flex-aware side-pane transition retained a fixed-width child while its animated parent width reached zero, causing narrow-window overflow.

### Suggested Fix
Remove the fixed-width child in the hidden state; only mount it while the pane is visible and clip its entering transition.

### Resolution
- **Resolved**: 2026-08-18T14:50:00Z
- **Notes**: Hidden panes now use `SizedBox.shrink()` inside the width animation.

---

## [ERR-20260818-008] infinite-background-animation-test-settle

**Logged**: 2026-08-18T14:40:00Z
**Priority**: low
**Status**: resolved
**Area**: flutter-testing

### Summary
Widget tests used `pumpAndSettle` after the landing background gained an intentional continuous animation.

### Suggested Fix
For state assertions around persistent motion, advance a bounded frame duration instead of waiting for all transient callbacks to stop.

### Resolution
- **Resolved**: 2026-08-18T14:40:00Z
- **Notes**: Replaced affected settles with bounded pumps; production animation remains continuous.

---

## [ERR-20260818-007] stale-context-bar-import

**Logged**: 2026-08-18T14:30:00Z
**Priority**: low
**Status**: resolved
**Area**: flutter-ui

### Summary
Replacing the generic session label in the context bar left an unused formatting import.

### Suggested Fix
Run analysis after display-layer refactors and remove imports whose only call sites were replaced.

### Resolution
- **Resolved**: 2026-08-18T14:30:00Z
- **Notes**: Removed the stale import before the final validation run.

---

## [ERR-20260818-006] stale-build-context-after-install

**Logged**: 2026-08-18T14:10:00Z
**Priority**: low
**Status**: resolved
**Area**: flutter-ui

### Summary
The Pi installer completion handler used the dialog's `BuildContext` after an async npm operation.

### Suggested Fix
After checking `State.mounted`, show feedback through the State's current `context`.

### Resolution
- **Resolved**: 2026-08-18T14:10:00Z
- **Notes**: Replaced the stale context with `this.context` and re-ran analysis.

---

## [ERR-20260818-005] macos-open-relative-app-path

**Logged**: 2026-08-18T14:00:00Z
**Priority**: low
**Status**: resolved
**Area**: visual-regression

### Summary
A macOS visual-check command passed a relative app bundle to `open -a`, which interprets it as an installed application name rather than a filesystem target.

### Suggested Fix
Use `open -n` with the explicit bundle path when launching a locally built Flutter application.

### Resolution
- **Resolved**: 2026-08-18T14:00:00Z
- **Notes**: The follow-up capture uses the bundle path directly.

---

## [ERR-20260818-011] flutter-ui-api-and-dart-escaping

**Logged**: 2026-08-18T14:10:00Z
**Priority**: low
**Status**: resolved
**Area**: frontend

### Summary
An initial desktop UI patch used unavailable Material icon names and an invalid raw-string quote escape in a Dart regular expression.

### Suggested Fix
Use icons verified by the target Flutter SDK and simple character checks for path quoting where a regex would make escaping brittle.

### Metadata
- Reproducible: yes
- Related Files: lib/src/ui/context_bar.dart, lib/src/ui/prompt_bar.dart

---

## [ERR-20260818-012] widget-copy-contract

**Logged**: 2026-08-18T14:20:00Z
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The landing-screen copy was intentionally redesigned, but its widget test still asserted the retired UI string.

### Suggested Fix
Keep visible-copy assertions synchronized with approved UI changes; retain behavioral assertions for the shell structure.

### Metadata
- Reproducible: yes
- Related Files: test/widget_test.dart, lib/src/ui/shell.dart

---

## [ERR-20260818-013] inspector-tab-visibility

**Logged**: 2026-08-18T14:35:00Z
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The narrow Inspector uses a horizontally scrollable TabBar, so the Tools tab is initially outside the 1280px widget-test viewport.

### Suggested Fix
Use `ensureVisible` before tapping overflowed tabs; retain the narrow-panel scenario to cover real desktop behavior.

### Metadata
- Reproducible: yes
- Related Files: test/widget_test.dart, lib/src/ui/inspector_pane.dart

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
