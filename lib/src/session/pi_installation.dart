import 'dart:convert';
import 'dart:io';

/// Local Pi CLI availability only. This never starts an agent or owns sessions.
/// Installation is intentionally explicit and uses Pi's documented npm package.
class PiInstallation {
  const PiInstallation({this.executable = 'pi'});

  static const package = '@earendil-works/pi-coding-agent';
  final String executable;

  Future<PiInstallationStatus> inspect() async {
    final installed = await _run(executable, const <String>['--version']);
    if (!installed.ok) {
      final npm = await _run('npm', const <String>['--version']);
      return PiInstallationStatus(
        available: false,
        npmAvailable: npm.ok,
        detail: npm.ok
            ? 'Pi is not installed'
            : 'npm is required to install Pi',
      );
    }
    final latest = await _run('npm', const <String>[
      'view',
      package,
      'version',
    ], timeout: const Duration(seconds: 4));
    final installedVersion = _firstLine(installed.output);
    final latestVersion = latest.ok ? _firstLine(latest.output) : null;
    return PiInstallationStatus(
      available: true,
      npmAvailable: true,
      installedVersion: installedVersion,
      latestVersion: latestVersion,
      detail: latestVersion == null
          ? 'Update check unavailable'
          : _isNewer(latestVersion, installedVersion)
          ? 'Update available'
          : 'Pi is up to date',
    );
  }

  Future<PiInstallationResult> installOrUpdate() async {
    final result = await _run('npm', const <String>[
      'install',
      '--global',
      '--ignore-scripts',
      package,
    ]);
    return PiInstallationResult(ok: result.ok, output: result.output);
  }

  static Future<_CommandResult> _run(
    String command,
    List<String> args, {
    Duration? timeout,
  }) async {
    try {
      final process = await Process.start(command, args);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      var timedOut = false;
      final exitCode = timeout == null
          ? await process.exitCode
          : await process.exitCode.timeout(
              timeout,
              onTimeout: () {
                timedOut = true;
                process.kill();
                return -1;
              },
            );
      final output = '${await stdout}\n${await stderr}'.trim();
      return _CommandResult(
        exitCode == 0 && !timedOut,
        timedOut ? 'Timed out while running $command.' : output,
      );
    } on ProcessException catch (error) {
      return _CommandResult(false, error.message);
    }
  }

  static String? _firstLine(String value) {
    final line = value
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    return line.isEmpty ? null : line.replaceFirst(RegExp(r'^v'), '');
  }

  static bool _isNewer(String latest, String? installed) {
    if (installed == null) return false;
    final parse = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch;
    final a = parse(latest);
    final b = parse(installed);
    if (a == null || b == null) return false;
    for (final index in <int>[1, 2, 3]) {
      final difference =
          int.parse(a.group(index)!) - int.parse(b.group(index)!);
      if (difference != 0) return difference > 0;
    }
    return false;
  }
}

class PiInstallationStatus {
  const PiInstallationStatus({
    required this.available,
    required this.npmAvailable,
    required this.detail,
    this.installedVersion,
    this.latestVersion,
  });

  final bool available;
  final bool npmAvailable;
  final String detail;
  final String? installedVersion;
  final String? latestVersion;

  bool get updateAvailable =>
      available &&
      latestVersion != null &&
      PiInstallation._isNewer(latestVersion!, installedVersion);
}

class PiInstallationResult {
  const PiInstallationResult({required this.ok, required this.output});
  final bool ok;
  final String output;
}

class _CommandResult {
  const _CommandResult(this.ok, this.output);
  final bool ok;
  final String output;
}
