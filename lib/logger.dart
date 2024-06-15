import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(methodCount: 3),
  filter: ProductionFilter()
);

final loggerNoStack = Logger(
  printer: PrettyPrinter(methodCount: 0),,
  filter: ProductionFilter()
);

void loggerDemo() {
  logger.d('Log message with 2 methods');

  loggerNoStack.i('Info message');

  loggerNoStack.w('Just a warning!');

  logger.e('Error! Something bad happened', error: 'Test Error');

  loggerNoStack.t({'key': 5, 'value': 'something'});

  Logger(printer: SimplePrinter(colors: true)).t('boom');
}
