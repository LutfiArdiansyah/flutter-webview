import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/error_logger_service.dart';

/// Screen to display error logs with copy functionality
class ErrorLogsScreen extends StatefulWidget {
  const ErrorLogsScreen({super.key});

  @override
  State<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends State<ErrorLogsScreen> {
  final ErrorLoggerService _loggerService = ErrorLoggerService();
  bool _copySuccess = false;

  /// Copy all logs to clipboard
  Future<void> _copyLogsToClipboard() async {
    try {
      final logs = _loggerService.getAllLogs();
      await Clipboard.setData(ClipboardData(text: logs));

      setState(() => _copySuccess = true);

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Logs copied to clipboard'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );

      // Reset flag after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _copySuccess = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error copying logs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Clear all logs
  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _loggerService.clearLogs();
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logs cleared'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = _loggerService.getLogs();
    final errorCount = _loggerService.getErrorCount();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Logs'),
        elevation: 0,
        actions: [
          if (logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearLogs,
              tooltip: 'Clear logs',
            ),
        ],
      ),
      body: logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No errors logged',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'App is running smoothly',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Summary card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Errors Detected: $errorCount',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                            const Text(
                              'You can copy and send these logs for support',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Copy button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _copyLogsToClipboard,
                      icon: Icon(
                        _copySuccess ? Icons.check : Icons.content_copy,
                      ),
                      label: Text(
                        _copySuccess ? 'Copied!' : 'Copy All Logs',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _copySuccess ? Colors.green : Colors.blue.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Logs list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return _LogCard(log: log);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// Individual log card widget
class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});
  final LogEntry log;

  @override
  Widget build(BuildContext context) {
    final isError = log.severity == 'ERROR';
    final isWarning = log.severity == 'WARNING';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with severity badge
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isError
                        ? Colors.red.shade100
                        : isWarning
                            ? Colors.orange.shade100
                            : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.severity,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isError
                          ? Colors.red.shade700
                          : isWarning
                              ? Colors.orange.shade700
                              : Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatTime(log.timestamp),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              log.message,
              style: const TextStyle(fontSize: 13),
            ),

            // Stack trace if available
            if (log.stackTrace != null && log.stackTrace!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    log.stackTrace!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Format time to HH:mm:ss
  String _formatTime(DateTime dateTime) =>
      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
}
