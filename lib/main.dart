import 'package:flutter/material.dart';
import 'package:pi_desktop/src/ui/app.dart';

export 'src/ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PiDesktopApp());
}
