import 'package:file_selector/file_selector.dart';

import '../session/pi_desktop_connection.dart';
import 'ui_preferences.dart';

Future<String?> pickWorkspaceDirectory() {
  return getDirectoryPath(confirmButtonText: 'Use this folder');
}

Future<List<XFile>> pickImageFiles() {
  return openFiles(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Images',
        extensions: <String>['png', 'jpg', 'jpeg', 'gif', 'webp'],
      ),
    ],
  );
}

Future<List<XFile>> pickAnyFiles() {
  return openFiles();
}

Future<void> chooseWorkspace({
  required PiDesktopConnection connection,
  required UiPreferences preferences,
}) async {
  final directory = await pickWorkspaceDirectory();
  if (directory == null || directory.trim().isEmpty) {
    return;
  }
  final path = directory.trim();
  await preferences.setWorkspacePath(path);
  await connection.reconnectIn(path);
}
