import 'dart:async';
import 'dart:ffi' show Abi;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'error_logger_service.dart';

/// Detects low-end devices (e.g. ARMv7 Android set-top boxes) so the UI can
/// skip GPU-heavy effects (backdrop blur, large shadows, looping
/// animations). Navigation and data behaviour never depend on it.
class DevicePerformanceService {
  const DevicePerformanceService._();

  static const MethodChannel _channel = MethodChannel(
    'com.example.webspace/device',
  );

  /// Devices with less total RAM than this are treated as low-end.
  static const int lowEndTotalMemoryBytes = 2 * 1024 * 1024 * 1024;

  /// Upper bound for the native query so startup is never held up.
  static const Duration initTimeout = Duration(milliseconds: 500);

  static bool _isLowEnd = evaluate(abi: Abi.current());

  /// Whether to use the lightweight visual profile. Before [initialize]
  /// completes this reflects the ABI check only.
  static bool get isLowEnd => _isLowEnd;

  /// Refines [isLowEnd] with the native memory class. Never throws: on
  /// timeout, error or non-Android platforms the ABI-based value is kept.
  static Future<void> initialize({
    MethodChannel channel = _channel,
    Abi? abi,
  }) async {
    final currentAbi = abi ?? Abi.current();
    try {
      final info = await channel
          .invokeMapMethod<String, Object?>('getMemoryInfo')
          .timeout(initTimeout);
      final isLowRam = info?['isLowRamDevice'];
      final totalMem = info?['totalMemBytes'];
      _isLowEnd = evaluate(
        abi: currentAbi,
        isLowRamDevice: isLowRam is bool ? isLowRam : null,
        totalMemoryBytes: totalMem is num ? totalMem.toInt() : null,
      );
    } on Exception catch (e) {
      // MissingPluginException (non-Android/tests), PlatformException or
      // TimeoutException: keep the ABI-only decision.
      _isLowEnd = evaluate(abi: currentAbi);
      if (e is! MissingPluginException) {
        ErrorLoggerService().logWarning(
          'Device Profile',
          'Memory info unavailable; using ABI-based profile.',
        );
      }
    }
  }

  /// Low-end when the process runs 32-bit ARM (ARMv7), Android reports a
  /// low-RAM device, or total RAM is below [lowEndTotalMemoryBytes].
  /// Unknown values (null, non-positive memory) are ignored.
  @visibleForTesting
  static bool evaluate({
    required Abi abi,
    bool? isLowRamDevice,
    int? totalMemoryBytes,
  }) {
    if (abi == Abi.androidArm) {
      return true;
    }
    if (isLowRamDevice ?? false) {
      return true;
    }
    return totalMemoryBytes != null &&
        totalMemoryBytes > 0 &&
        totalMemoryBytes < lowEndTotalMemoryBytes;
  }

  /// Overrides the profile (tests only).
  @visibleForTesting
  // ignore: use_setters_to_change_properties
  static void debugSetLowEnd({required bool isLowEnd}) => _isLowEnd = isLowEnd;
}
