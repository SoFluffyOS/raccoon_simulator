import 'package:flutter/foundation.dart';

/// Logs a line to the developer console.
void printLog(Object? message) => debugPrint('[simulator] $message');

/// Logs an error and its stack trace to the developer console.
void printError(Object? error, [StackTrace? stackTrace]) {
  debugPrint('[simulator] error: $error');
  if (stackTrace case final trace?) debugPrint('$trace');
}
