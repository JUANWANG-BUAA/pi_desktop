import 'dart:io';

/// Pinned Pi CLI/package version from `docs/pi-baseline.md`.
///
/// Connecting to any other global `pi` is a protocol assumption failure, not a
/// soft warning. Tests that spawn a fixture executable are exempt because the
/// basename is not `pi`.
const piBaselineVersion = '0.84.2';

/// Override the spawned binary (bundled runtime or verified local path).
const piDesktopRuntimeEnv = 'PI_DESKTOP_RUNTIME';

class PiVersionMismatchException implements Exception {
  PiVersionMismatchException(this.found, {required this.executable});

  final String? found;
  final String executable;

  @override
  String toString() {
    if (found == null) {
      return 'Pi executable "$executable" did not report a version. '
          'Pi Desktop requires the pinned runtime $piBaselineVersion.';
    }
    return 'Pi $found is not the pinned RPC baseline $piBaselineVersion. '
        'Pi Desktop will not connect to an unverified global pi. '
        'Install $piBaselineVersion or set $piDesktopRuntimeEnv to a '
        'verified $piBaselineVersion binary.';
  }
}

class PiRuntime {
  const PiRuntime._();

  static String resolveExecutable(String requested) {
    final override = Platform.environment[piDesktopRuntimeEnv]?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return requested;
  }

  /// Version gating applies to a real `pi` binary, not RPC fixtures.
  static bool shouldEnforceBaseline(String executable) {
    final name = executable.split(RegExp(r'[\\/]')).last.toLowerCase();
    return name == 'pi' || name == 'pi.exe';
  }

  static String? readVersion(String executable) {
    try {
      final result = Process.runSync(executable, const <String>['--version']);
      if (result.exitCode != 0) {
        return null;
      }
      return parseVersion('${result.stdout}');
    } on ProcessException {
      return null;
    }
  }

  static String? parseVersion(String stdout) {
    final line = stdout.trim().split(RegExp(r'\r?\n')).first.trim();
    if (line.isEmpty) {
      return null;
    }
    final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(line);
    if (match != null) {
      return match.group(1);
    }
    return line.replaceFirst(RegExp(r'^v'), '');
  }

  static void enforceBaseline(String executable) {
    if (!shouldEnforceBaseline(executable)) {
      return;
    }
    final version = readVersion(executable);
    if (version != piBaselineVersion) {
      throw PiVersionMismatchException(version, executable: executable);
    }
  }
}
