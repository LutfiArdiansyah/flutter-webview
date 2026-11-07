import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'error_logger_service.dart';
import 'oauth_user_agent.dart';

/// Settings shared by the main WebView and sign-in popups.
///
/// Always applied as a whole (never a partial update) so a User-Agent
/// switch cannot reset any other setting to the plugin default.
InAppWebViewSettings buildWebViewSettings({String? userAgent}) =>
    InAppWebViewSettings(
      javaScriptEnabled: true,
      // Allow media to auto-play without requiring user interaction
      // (vital for Anime streaming).
      mediaPlaybackRequiresUserGesture: false,
      useShouldOverrideUrlLoading: true,
      // Popups are only created for allowlisted URLs (see onCreateWindow).
      // Without a user gesture window.open stays blocked, which keeps
      // pop-under ads out.
      supportMultipleWindows: true,
      javaScriptCanOpenWindowsAutomatically: false,
      // Do not reveal the app package name in X-Requested-With (no-op when
      // the device WebView does not support it).
      requestedWithHeaderOriginAllowList: const <String>{},
      userAgent: userAgent,
    );

/// Switches one WebView's User-Agent between the device default and the
/// browser-like UA used on Google account hosts ([OAuthUserAgent]).
///
/// Calls are serialized and only reach the platform when the UA actually
/// changes.
class WebViewUserAgentSwitcher {
  WebViewUserAgentSwitcher({required String? initialUserAgent})
    : _current = initialUserAgent;

  static Future<String?>? _defaultUserAgent;

  /// The device WebView's default UA, fetched once per app run. Null if it
  /// cannot be read, in which case no switching happens (fail closed: the
  /// WebView keeps its default UA).
  static Future<String?> defaultUserAgent() =>
      _defaultUserAgent ??= _loadDefaultUserAgent();

  static Future<String?> _loadDefaultUserAgent() async {
    try {
      final ua = await InAppWebViewController.getDefaultUserAgent();
      return ua.isEmpty ? null : ua;
    } on Exception catch (e) {
      ErrorLoggerService().logWarning(
        'User-Agent',
        'Default User-Agent unavailable: $e',
      );
      return null;
    }
  }

  /// UA to create a WebView with when it will first load [url].
  static Future<String?> initialUserAgentFor(String? url) async {
    final defaultUa = await defaultUserAgent();
    return defaultUa == null
        ? null
        : OAuthUserAgent.userAgentFor(url, defaultUa);
  }

  String? _current;
  Future<void> _pending = Future.value();

  /// Applies the UA required for [url] before it loads.
  Future<void> applyFor(InAppWebViewController controller, String? url) {
    final next = _pending.then((_) => _apply(controller, url));
    // Keep the queue alive even if one switch fails.
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<void> _apply(InAppWebViewController controller, String? url) async {
    final defaultUa = await defaultUserAgent();
    if (defaultUa == null) {
      return;
    }
    final target = OAuthUserAgent.userAgentFor(url, defaultUa);
    if (target == (_current ?? defaultUa)) {
      return;
    }
    try {
      await controller.setSettings(
        settings: buildWebViewSettings(userAgent: target),
      );
      _current = target;
    } on Exception catch (e) {
      debugPrint('User-Agent switch failed: $e');
      ErrorLoggerService().logWarning(
        'User-Agent',
        'User-Agent switch failed.',
      );
    }
  }
}
