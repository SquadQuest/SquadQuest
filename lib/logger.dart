import 'package:logger/logger.dart';

const _productionLogging =
    String.fromEnvironment('PRODUCTION_LOGGING', defaultValue: 'false') ==
        'false';
final _logFilter =
    _productionLogging ? DevelopmentFilter() : ProductionFilter();

final loggerSimple = Logger(printer: SimplePrinter(), filter: _logFilter);

final loggerWithStack =
    Logger(printer: PrettyPrinter(methodCount: 3), filter: _logFilter);

final logger =
    Logger(printer: PrettyPrinter(methodCount: 0), filter: _logFilter);

DateTime? _lastTimedLog;
void loggerTimed(String message) {
  final now = DateTime.now();
  if (_lastTimedLog != null) {
    final diff = now.difference(_lastTimedLog!);
    logger.t('$message: $diff');
  } else {
    logger.t(message);
  }
  _lastTimedLog = now;
}

void log(String message, {Level level = Level.trace}) {
  loggerSimple.log(level, message);
}
