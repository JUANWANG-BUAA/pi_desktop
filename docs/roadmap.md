# Public roadmap

This is the **external** milestone list. The binding architecture contract,
including what this client must never become, lives in [`TODO.md`](../TODO.md).
New contributors should start with [`CONTRIBUTING.md`](../CONTRIBUTING.md), not
the 26KB contract file.

## Now

- Keep HEAD, README, and CI in agreement.
- Land GitHub Actions on every push/PR (format, analyze, tests, three-platform
  debug builds).
- First **public** source release of this repository (MIT).

## Next (M5, smallest shippable)

First downloadable build targets **macOS**, which is already verified locally.

- Bundle a verified Pi runtime; do not require a user-global `npm` `pi`.
- macOS signing and notarization.
- Prove upgrades do not break Pi Sessions; uninstall does not delete Pi data.
- Human review against TODO.md §15 (one-ticket veto list).
- Compatibility matrix: desktop version ↔ Pi version ↔ RPC baseline ↔ Session
  JSONL version. Process sketch is in [`pi-baseline.md`](pi-baseline.md);
  execution still needs a tagged release workflow.

Windows and Linux installers follow once CI builds stay green.

## After the first release

- Accessibility: M4 still only has partial `Semantics`.
- M2 provider/tool behavior matrix as **opt-in** integration tests (credentials
  required; never on the default CI path; no quota burn).
- M3 full resource diagnostics: wait for upstream `list_resources`, then delete
  the `~/.pi` filesystem preview. Spec: [`rpc-upstream.md`](rpc-upstream.md).
- Replace `com.example` bundle/company placeholders once the public reverse-DNS
  identity is chosen.
- Dependabot (or equivalent) for Dart deps and GitHub Actions, gated by the
  Pi baseline bump process.

## Explicitly not a desktop feature

Anything in TODO.md §0.3 / §15: a second agent loop, memory/plan/workflow
store, prompt rewriting, background auto-continue, direct provider calls, a
private plugin API, or TUI scraping.
