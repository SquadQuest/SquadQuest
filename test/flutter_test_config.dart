import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';
import 'package:test_screen/test_screen.dart';

import './mocks.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  initializeDateFormatting();

  initializeDefaultTestScreenConfig(buildTestScreenConfig());

  return testMain();
}
