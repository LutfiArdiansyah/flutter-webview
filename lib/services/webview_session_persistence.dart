import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'error_logger_service.dart';

/// Makes sure WebView cookies (login sessions) reach disk.
///
/// Android's CookieManager only writes cookies to disk periodically, so a
/// session created just before the app is closed, swiped away, or a set-top
/// box is powered off can be lost. Flushing on page load, when the app goes
/// to the background, and before exiting keeps the user signed in.
class WebViewSessionPersistence {
  WebViewSessionPersistence({
    Future<void> Function()? flushCookies,
    DateTime Function()? now,
    this.minPageLoadInterval = const Duration(seconds: 5),
    this.flushTimeout = const Duration(seconds: 2),
  }) : _flushCookies = flushCookies ?? _flushPlatformCookies,
       _now = now ?? DateTime.now;

  /// Minimum time between flushes triggered by page loads.
  final Duration minPageLoadInterval;

  /// Upper bound for one flush, so exiting the app is never held up.
  final Duration flushTimeout;

  final Future<void> Function() _flushCookies;
  final DateTime Function() _now;
  Future<void>? _inFlight;
  DateTime? _lastFlushStartedAt;

  static Future<void> _flushPlatformCookies() async {
    // CookieManager.flush is Android-only; other platforms persist cookies
    // on their own.
    if (Platform.isAndroid) {
      await CookieManager.instance().flush();
    }
  }

  /// Flushes cookies now. Concurrent calls share one flush. Never throws:
  /// failures and timeouts are logged as warnings.
  Future<void> flush() {
    final existing = _inFlight;
    if (existing != null) {
      return existing;
    }
    final current = _runFlush();
    _inFlight = current;
    unawaited(
      current.whenComplete(() {
        if (identical(_inFlight, current)) {
          _inFlight = null;
        }
      }),
    );
    return current;
  }

  /// Flushes after a page load, at most once per [minPageLoadInterval], so
  /// browsing does not cause a disk write per page.
  Future<void> flushAfterPageLoad() {
    final last = _lastFlushStartedAt;
    if (_inFlight == null &&
        last != null &&
        _now().difference(last) < minPageLoadInterval) {
      return Future.value();
    }
    return flush();
  }

  Future<void> _runFlush() async {
    _lastFlushStartedAt = _now();
    try {
      await _flushCookies().timeout(flushTimeout);
    } on Exception catch (e) {
      debugPrint('Cookie flush failed: $e');
      ErrorLoggerService().logWarning(
        'Session Persistence',
        'Saving WebView cookies to disk failed.',
      );
    }
  }
}
