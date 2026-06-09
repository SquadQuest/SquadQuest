/// A failure surfaced from the API, carrying the stable `code` from the error
/// envelope (specs/api/conventions.md). UI/logic branch on `code`, never message.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.upgradeRequired = false,
  });

  final int statusCode;
  final String code;
  final String message;
  final bool upgradeRequired; // true on 426

  @override
  String toString() => 'ApiException($statusCode $code): $message';
}
