import 'dart:async';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // setUpAll(() async {
  // await loadAppFonts
  // final FontLoader fontLoader = FontLoader('Roboto')..addFont(someFont);
  // await fontLoader.load();
  // });

  await testMain();
}
