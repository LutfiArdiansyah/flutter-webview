import 'package:intl/intl.dart';

/// Error log entry
class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.severity,
    required this.title,
    required this.message,
    this.stackTrace,
  });
  final DateTime timestamp;
  final String severity; // ERROR, WARNING, INFO
  final String title;
  final String message;
  final String? stackTrace;

  /// Format log entry as string
  String format() {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final time = dateFormat.format(timestamp);

    final buffer = StringBuffer();
    buffer.writeln('[$time] [$severity] $title');
    buffer.writeln('Message: $message');

    if (stackTrace != null && stackTrace!.isNotEmpty) {
      buffer.writeln('\nStackTrace:');
      buffer.writeln(stackTrace);
    }
    buffer.writeln('---');

    return buffer.toString();
  }
}

/// Error Logger Service - Singleton
class ErrorLoggerService {
  // Keep only last 50 logs

  factory ErrorLoggerService() {
    return _instance;
  }

  ErrorLoggerService._internal();
  static final ErrorLoggerService _instance = ErrorLoggerService._internal();

  final List<LogEntry> _logs = [];
  static const int _maxLogs = 50;

  /// Log an error
  void logError(
    String title,
    String message, {
    String? stackTrace,
  }) {
    _addLog(
      severity: 'ERROR',
      title: title,
      message: message,
      stackTrace: stackTrace,
    );
  }

  /// Log a warning
  void logWarning(
    String title,
    String message,
  ) {
    _addLog(
      severity: 'WARNING',
      title: title,
      message: message,
    );
  }

  /// Log info
  void logInfo(
    String title,
    String message,
  ) {
    _addLog(
      severity: 'INFO',
      title: title,
      message: message,
    );
  }

  /// Add log entry
  void _addLog({
    required String severity,
    required String title,
    required String message,
    String? stackTrace,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      severity: severity,
      title: title,
      message: message,
      stackTrace: stackTrace,
    );

    _logs.add(entry);

    // Keep only last N logs
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
  }

  /// Get all logs as formatted string
  String getAllLogs() {
    if (_logs.isEmpty) {
      return 'No logs available';
    }

    final buffer = StringBuffer();
    buffer.writeln('=== ERROR LOG ===');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Total Errors: ${_logs.length}');
    buffer.writeln('');

    for (final log in _logs) {
      buffer.write(log.format());
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// Get latest error
  LogEntry? getLatestError() {
    try {
      return _logs.lastWhere((log) => log.severity == 'ERROR');
    } catch (e) {
      return null;
    }
  }

  /// Get error count
  int getErrorCount() => _logs.where((log) => log.severity == 'ERROR').length;

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
  }

  /// Get logs list (for UI)
  List<LogEntry> getLogs() => List.unmodifiable(_logs.reversed);
}
