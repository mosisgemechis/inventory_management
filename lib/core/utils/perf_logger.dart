import 'package:flutter/foundation.dart';

class PerfLogger {
  static void logPerformance(String operation, int milliseconds) {
    debugPrint('[PERF] $operation: $milliseconds ms');
  }

  static void logSlowQuery(String operation, int milliseconds) {
    if (milliseconds > 100) {
      debugPrint('[SLOW QUERY] $operation took $milliseconds ms');
    }
  }

  static void info(String message) {
    debugPrint('[INFO] $message');
  }

  static void warning(String message) {
    debugPrint('[WARNING] $message');
  }

  static void error(String message, [dynamic error, StackTrace? stack]) {
    debugPrint('[ERROR] $message');
    if (error != null) debugPrint('Error: $error');
    if (stack != null) debugPrint('Stack: $stack');
  }
}
