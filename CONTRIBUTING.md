# Contributing

Pi Desktop is a **thin Flutter client** for the official Pi CLI (`pi --mode rpc`).
Pi is the only agent and the only source of truth. Please read this before
sending a pull request.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## 15-minute local run (macOS)

1. Install the pinned toolchain from [`docs/pi-baseline.md`](docs/pi-baseline.md):
   Flutter **3.47.0**, Dart **3.13.0**, Node.js **≥22.19.0**, Pi **0.84.2**.
2. Clone this repository.
3. Install Pi for development only (releases must not depend on this):

   ```bash
   npm install --global @earendil-works/pi-coding-agent@0.84.2
   pi --version   # must print 0.84.2
   ```

4. Run the desktop app:

   ```bash
   flutter pub get
   flutter run -d macos
   ```

Windows/Linux: `flutter run -d windows` / `flutter run -d linux` after the
matching Flutter desktop SDK is enabled. Those hosts are covered by CI builds;
the development golden screenshots are generated on macOS.

### Common failures

| Symptom | What to check |
| --- | --- |
| Connection refused / version gate | `pi --version` is not `0.84.2`. Override the binary with `PI_DESKTOP_RUNTIME` only if that file is the pinned baseline. |
| Tests skip smoke cases | Pi is not on `PATH`. Widget, RPC fixture, and boundary tests still run. |
| Golden mismatch | You changed visible chrome. Update with `flutter test test/ui_snapshot_test.dart --update-goldens` on macOS. |
| Pre-commit hook missing | Git hooks are local. Run `tool/install_hooks.sh` once per clone. |

## Before every commit

```bash
tool/check.sh
```

That is the same gate CI runs: `dart format`, `flutter analyze`, `flutter test`
(including `test/boundary/boundary_scan_test.dart`), and `git diff --check`.

Install it as a pre-commit hook:

```bash
tool/install_hooks.sh
```

## Pull requests

- One concern per PR. Do not mix UI polish, protocol changes, and docs-only work
  unless they are inseparable.
- Do not commit API keys, Pi Session JSONL, `.env`, or `build/` artifacts.
- Do **not** invent RPC commands. Allowed command names are listed in TODO.md
  §3.2. New protocol needed by the UI belongs in
  [`docs/rpc-upstream.md`](docs/rpc-upstream.md) and an upstream Pi issue, not
  in this client.
- Do not add a second session store, provider SDK, agent loop, or desktop plugin
  API. The boundary scanner will fail the build.
- Update [`docs/pi-baseline.md`](docs/pi-baseline.md) **before** bumping the Pi
  or Flutter pin, then re-run the suite (smoke tests assert the Pi version).

Use the PR template checklist. Maintainers will not merge a PR that skips
`tool/check.sh`.

## Where to look

| File | Role |
| --- | --- |
| [`TODO.md`](TODO.md) | Binding product/architecture contract (not a beginner tutorial) |
| [`docs/architecture.md`](docs/architecture.md) | How the client talks to Pi |
| [`docs/roadmap.md`](docs/roadmap.md) | Public milestone list |
| [`docs/rpc-upstream.md`](docs/rpc-upstream.md) | RPC commands we are requesting from Pi |
| [`CHANGELOG.md`](CHANGELOG.md) | User-visible changes |

## License

Contributions are accepted under the [MIT License](LICENSE).
