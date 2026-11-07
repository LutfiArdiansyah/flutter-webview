import 'dart:io';

import 'package:flutter/services.dart';

import 'error_logger_service.dart';

/// Native screen-orientation controls not exposed by [SystemChrome].
class ScreenOrientationService {
  /// Creates the service. [isAndroid] and [channel] are injectable for tests.
  ScreenOrientationService({
    bool? isAndroid,
    MethodChannel? channel,
    ErrorLoggerService? errorLogger,
  }) : _isAndroid = isAndroid ?? Platform.isAndroid,
       _channel = channel ?? const MethodChannel(channelName),
       _errorLogger = errorLogger ?? ErrorLoggerService();

  /// Method channel name; must match `MainActivity.kt`.
  static const String channelName = 'com.example.webspace/orientation';

  /// Method that switches the activity to sensor-driven landscape.
  static const String setSensorLandscapeMethod = 'setSensorLandscape';

  final bool _isAndroid;
  final MethodChannel _channel;
  final ErrorLoggerService _errorLogger;

  /// Lets landscape flip 180° with the device even while system auto-rotate
  /// is locked, like YouTube's fullscreen player.
  ///
  /// On Android, [SystemChrome.setPreferredOrientations] with both landscape
  /// orientations maps to `SCREEN_ORIENTATION_USER_LANDSCAPE`, which honours
  /// the rotation lock; this upgrades it to `SENSOR_LANDSCAPE`. Call it after
  /// [SystemChrome.setPreferredOrientations] so it is not overridden. Other
  /// platforms already follow the sensor, so this is a no-op there. Failures
  /// are logged and leave the plain landscape lock in place.
  Future<void> setLandscapeFollowingSensor() async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(setSensorLandscapeMethod);
    } on PlatformException catch (e) {
      _errorLogger.logError('Orientation Error', e.toString());
    } on MissingPluginException catch (e) {
      _errorLogger.logError('Orientation Error', e.toString());
    }
  }
}
