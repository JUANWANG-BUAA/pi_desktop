# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Version numbers follow [SemVer](https://semver.org/).

Desktop version, Pi version, and RPC wire baseline are pinned together in
[`docs/pi-baseline.md`](docs/pi-baseline.md). A Pi bump is a **breaking**
desktop release until a compatibility matrix exists.

## [Unreleased]

### Added

- MIT license, contributing guide, code of conduct, security policy, and GitHub
  Actions for format/analyze/test plus macOS, Linux, and Windows debug builds.
- Message Copy; user-message Revert through official Pi `fork`.
- Pi baseline connect gate (`pi --version` must match `0.84.2`) and
  `PI_DESKTOP_RUNTIME` override.
- Crash diagnostics: retain Pi stderr and write `last_pi_crash.log`.
- Upstream RPC request for `get_runtime_info`, `list_sessions`,
  `list_resources`, and prompt `files[]` (`docs/rpc-upstream.md`).

### Changed

- Folded tool/thinking cards cap height and scroll inside the card.
- Reading font is a real family (system / sans / serif / rounded / mono) applied
  through `ThemeData` and Markdown, with a single text-scale path.
- Archive and Inspector label filesystem inventory as a preview until official
  `list_*` commands exist.

### Removed

- Fake non-image attachments that spliced `Attached files: @path` into the
  prompt. Images still use official `ImageContent`.

## [0.1.0] - 2026-08-19

### Added

- Flutter Desktop thin client for Pi `0.84.2` `pi --mode rpc`.
- Session restore, prompt/steer/follow-up/abort, tool and thinking display,
  tree/fork/clone, compaction/retry, model and thinking-level controls.
- Extension UI protocol and slash-command suggestions from `get_commands`.
- Boundary contract in `TODO.md`, enforced by
  `test/boundary/boundary_scan_test.dart` and `tool/check.sh`.
