import 'dart:async';
import 'dart:ffi' show Abi;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webspace/services/device_performance_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/device');
  const gib = 1024 * 1024 * 1024;

  void mockChannel(Future<Object?>? Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() => mockChannel((_) => null));

  group('DevicePerformanceService.evaluate', () {
    test('32-bit ARM is always low-end', () {
      expect(DevicePerformanceService.evaluate(abi: Abi.androidArm), isTrue);
      expect(
        DevicePerformanceService.evaluate(
          abi: Abi.androidArm,
          isLowRamDevice: false,
          totalMemoryBytes: 8 * gib,
        ),
        isTrue,
      );
    });

    test('64-bit with enough RAM is not low-end', () {
      expect(DevicePerformanceService.evaluate(abi: Abi.androidArm64), isFalse);
      expect(
        DevicePerformanceService.evaluate(
          abi: Abi.androidArm64,
          isLowRamDevice: false,
          totalMemoryBytes: 2 * gib,
        ),
        isFalse,
      );
    });

    test('low-RAM flag or less than 2 GiB makes it low-end', () {
      expect(
        DevicePerformanceService.evaluate(
          abi: Abi.androidArm64,
          isLowRamDevice: true,
        ),
        isTrue,
      );
      expect(
        DevicePerformanceService.evaluate(
          abi: Abi.androidArm64,
          totalMemoryBytes: 2 * gib - 1,
        ),
        isTrue,
      );
    });

    test('ignores unknown or invalid memory values', () {
      for (final mem in [null, 0, -1]) {
        expect(
          DevicePerformanceService.evaluate(
            abi: Abi.androidArm64,
            totalMemoryBytes: mem,
          ),
          isFalse,
          reason: '$mem',
        );
      }
    });
  });

  group('DevicePerformanceService.initialize', () {
    test('uses native memory info', () async {
      mockChannel((call) async {
        expect(call.method, 'getMemoryInfo');
        return {'isLowRamDevice': false, 'totalMemBytes': gib};
      });
      await DevicePerformanceService.initialize(
        channel: channel,
        abi: Abi.androidArm64,
      );
      expect(DevicePerformanceService.isLowEnd, isTrue);

      mockChannel(
        (_) async => {'isLowRamDevice': false, 'totalMemBytes': 4 * gib},
      );
      await DevicePerformanceService.initialize(
        channel: channel,
        abi: Abi.androidArm64,
      );
      expect(DevicePerformanceService.isLowEnd, isFalse);
    });

    test('tolerates malformed values', () async {
      mockChannel((_) async => {'isLowRamDevice': 'yes', 'totalMemBytes': 'x'});
      await DevicePerformanceService.initialize(
        channel: channel,
        abi: Abi.androidArm64,
      );
      expect(DevicePerformanceService.isLowEnd, isFalse);
    });

    test('falls back to the ABI on platform errors', () async {
      mockChannel((_) async => throw PlatformException(code: 'UNAVAILABLE'));
      await DevicePerformanceService.initialize(
        channel: channel,
        abi: Abi.androidArm,
      );
      expect(DevicePerformanceService.isLowEnd, isTrue);
    });

    test('falls back to the ABI when the channel is missing', () async {
      mockChannel(null);
      await DevicePerformanceService.initialize(
        channel: channel,
        abi: Abi.androidArm64,
      );
      expect(DevicePerformanceService.isLowEnd, isFalse);
    });

    test('does not wait longer than the timeout', () async {
      final never = Completer<Object?>();
      mockChannel((_) => never.future);
      final stopwatch = Stopwatch()..start();
      await DevicePerformanceService.initialize(
        channel: channel,
        abi: Abi.androidArm,
      );
      expect(
        stopwatch.elapsed,
        lessThan(
          DevicePerformanceService.initTimeout + const Duration(seconds: 2),
        ),
      );
      expect(DevicePerformanceService.isLowEnd, isTrue);
    });
  });
}
