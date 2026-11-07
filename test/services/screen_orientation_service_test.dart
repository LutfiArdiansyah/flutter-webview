import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webspace/services/error_logger_service.dart';
import 'package:webspace/services/screen_orientation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(ScreenOrientationService.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final errorLogger = ErrorLoggerService();
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    errorLogger.clearLogs();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  void mockChannel(Future<Object?>? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  group('setLandscapeFollowingSensor', () {
    test('invokes setSensorLandscape on Android', () async {
      mockChannel((_) async => null);

      await ScreenOrientationService(isAndroid: true)
          .setLandscapeFollowingSensor();

      expect(calls, hasLength(1));
      expect(
        calls.single.method,
        ScreenOrientationService.setSensorLandscapeMethod,
      );
      expect(errorLogger.getErrorCount(), 0);
    });

    test('does not touch the channel on other platforms', () async {
      mockChannel((_) async => null);

      await ScreenOrientationService(isAndroid: false)
          .setLandscapeFollowingSensor();

      expect(calls, isEmpty);
      expect(errorLogger.getErrorCount(), 0);
    });

    test('logs and swallows PlatformException', () async {
      mockChannel((_) async => throw PlatformException(code: 'failed'));

      await expectLater(
        ScreenOrientationService(isAndroid: true).setLandscapeFollowingSensor(),
        completes,
      );

      expect(calls, hasLength(1));
      expect(errorLogger.getErrorCount(), 1);
      expect(errorLogger.getLatestError()?.title, 'Orientation Error');
    });

    test('logs and swallows MissingPluginException', () async {
      // No handler registered: the channel throws MissingPluginException.
      await expectLater(
        ScreenOrientationService(isAndroid: true).setLandscapeFollowingSensor(),
        completes,
      );

      expect(errorLogger.getErrorCount(), 1);
      expect(errorLogger.getLatestError()?.title, 'Orientation Error');
    });
  });
}
