import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../models/webview_config.dart';
import 'error_logger_service.dart';

/// Service to load website entries from remote JSON configuration
class UrlLoaderService {
  final ErrorLoggerService _errorLogger = ErrorLoggerService();

  /// Fetch website list from GitHub JSON
  ///
  /// Throws:
  /// - [TimeoutException] if request times out
  /// - [SocketException] if network error occurs
  /// - [FormatException] if JSON format is invalid
  /// - [HttpException] if HTTP request fails
  /// - [ArgumentError] if URL is invalid
  Future<List<WebsiteConfig>> fetchWebsites() async {
    try {
      final response = await http
          .get(
            Uri.parse(AppConstants.jsonUrl),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'WebSpace/1.0',
            },
          )
          .timeout(
            const Duration(seconds: AppConstants.requestTimeoutSeconds),
            onTimeout: () => throw TimeoutException('URL fetch timeout'),
          );

      if (response.statusCode == 200) {
        return _parseAndValidateResponse(response.body);
      } else {
        throw HttpException(
          'HTTP ${response.statusCode}: Failed to fetch configuration',
        );
      }
    } on SocketException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } on FormatException {
      rethrow;
    }
  }

  /// Parse and validate the JSON response
  ///
  /// Returns the valid website list
  /// Throws [FormatException] if JSON is invalid or data is invalid
  List<WebsiteConfig> _parseAndValidateResponse(String responseBody) {
    try {
      final json = jsonDecode(responseBody);
      if (json is! List) {
        throw const FormatException(
          'Expected a list of website configurations',
        );
      }

      final websites = <WebsiteConfig>[];
      for (final item in json) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final config = WebsiteConfig.fromJson(item);

        if (!_isValidUrl(config.webviewUrl)) {
          throw FormatException('Invalid URL: ${config.webviewUrl}');
        }

        _warnAboutDroppedAllowedEntries(config.websiteName, item['allowed']);

        websites.add(config);
      }

      if (websites.isEmpty) {
        throw const FormatException('No valid website configuration found');
      }

      return websites;
    } catch (e) {
      if (e is FormatException) {
        rethrow;
      }
      throw FormatException('Failed to parse JSON: $e');
    }
  }

  /// Logs `allowed` entries that were skipped, so config mistakes are
  /// visible without rejecting the whole configuration.
  void _warnAboutDroppedAllowedEntries(String websiteName, Object? rawAllowed) {
    if (rawAllowed != null && rawAllowed is! List) {
      _errorLogger.logWarning(
        'Allowlist Config',
        '"allowed" for $websiteName must be a list; ignored.',
      );
      return;
    }
    final parsed = WebsiteConfig.parseAllowedJson(rawAllowed);
    if (parsed.invalidEntries.isNotEmpty) {
      _errorLogger.logWarning(
        'Allowlist Config',
        'Invalid "allowed" entries for $websiteName ignored: '
            '${parsed.invalidEntries.join(', ')}',
      );
    }
    if (parsed.truncated) {
      _errorLogger.logWarning(
        'Allowlist Config',
        '"allowed" for $websiteName exceeds '
            '${AppConstants.maxAllowedHosts} entries; extra entries ignored.',
      );
    }
  }

  /// Validate URL format
  ///
  /// Returns true if URL is valid, false otherwise
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } on Exception {
      return false;
    }
  }
}
