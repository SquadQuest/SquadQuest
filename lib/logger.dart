import 'package:logger/logger.dart';

const _productionLogging =
    String.fromEnvironment('PRODUCTION_LOGGING', defaultValue: 'false') ==
        'false';
final _logFilter =
    _productionLogging ? DevelopmentFilter() : ProductionFilter();

final loggerWithStack =
    Logger(printer: PrettyPrinter(methodCount: 3), filter: _logFilter);

final logger =
    Logger(printer: PrettyPrinter(methodCount: 0), filter: _logFilter);
