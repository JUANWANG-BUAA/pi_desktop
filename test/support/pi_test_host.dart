import 'dart:io';

/// Pi version pinned by `docs/pi-baseline.md`. Upgrading Pi requires
/// updating that baseline and re-running the RPC compatibility checks.
const piBaselineVersion = '0.84.2';

/// Version reported by the `pi` executable on PATH, or null when missing.
String? piVersion() {
  try {
    final result = Process.runSync('pi', <String>['--version']);
    if (result.exitCode != 0) {
      return null;
    }
    final line = '${result.stdout}'.trim().split(RegExp(r'\r?\n')).first.trim();
    return line.replaceFirst(RegExp(r'^v'), '');
  } on ProcessException {
    return null;
  }
}

bool get isPiAvailable => piVersion() != null;
