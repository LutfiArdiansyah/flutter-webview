import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../models/webview_config.dart';

/// Service to load WebView URL from remote JSON configuration
class UrlLoaderService {
  /// Fetch WebView URL from GitHub JSON
  ///
  /// Throws:
  /// - [TimeoutException] if request times out
  /// - [SocketException] if network error occurs
  /// - [FormatException] if JSON format is invalid
  /// - [HttpException] if HTTP request fails
  /// - [ArgumentError] if URL is invalid
  Future<String> fetchWebViewUrl() async {
    try {
      final response = await http
          .get(
            Uri.parse(AppConstants.jsonUrl),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'AnimeWebView/1.0',
            },
          )
          .timeout(
            Duration(seconds: AppConstants.requestTimeoutSeconds),
            onTimeout: () =>
                throw TimeoutException('URL fetch timeout'),
          );

      if (response.statusCode == 200) {
        return _parseAndValidateResponse(response.body);
      } else {
        throw HttpException(
            'HTTP ${response.statusCode}: Failed to fetch configuration');
      }
    } on SocketException catch (e) {
      rethrow;
    } on TimeoutException catch (e) {
      rethrow;
    } on FormatException catch (e) {
      rethrow;
    }
  }

  /// Parse and validate the JSON response
  ///
  /// Returns the valid WebView URL
  /// Throws [FormatException] if JSON is invalid or URL is invalid
  String _parseAndValidateResponse(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final config = WebViewConfig.fromJson(json);
      
      if (!_isValidUrl(config.webviewUrl)) {
        throw FormatException('Invalid URL: ${config.webviewUrl}');
      }
      
      return config.webviewUrl;
    } catch (e) {
      if (e is FormatException) {
        rethrow;
      }
      throw FormatException('Failed to parse JSON: $e');
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
    } catch (e) {
      return false;
    }
  }
}
