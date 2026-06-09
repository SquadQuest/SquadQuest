import 'package:flutter_driver/driver_extension.dart';

import 'package:squadquest/main.dart' as app;

// Driver entrypoint: enables the Flutter Driver extension so the app can be
// driven/inspected over the VM service (e.g. via the Dart MCP server) without
// touching the production main(). Run with:
//   flutter run test_driver/app.dart -d macos
void main() {
  enableFlutterDriverExtension();
  app.main();
}
