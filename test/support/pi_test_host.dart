import 'package:pi_desktop/src/session/pi_baseline.dart';

export 'package:pi_desktop/src/session/pi_baseline.dart' show piBaselineVersion;

/// Version reported by the `pi` executable on PATH, or null when missing.
String? piVersion() => PiRuntime.readVersion('pi');

bool get isPiAvailable => piVersion() != null;
