import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:webspace/services/webview_session_persistence.dart';

void main() {
  late int flushCount;
  late DateTime now;

  WebViewSessionPersistence create({
    Future<void> Function()? flush,
    Duration flushTimeout = const Duration(seconds: 2),
  }) => WebViewSessionPersistence(
    flushCookies:
        flush ??
        () async {
          flushCount++;
        },
    now: () => now,
    flushTimeout: flushTimeout,
  );

  setUp(() {
    flushCount = 0;
    now = DateTime(2026, 11, 8, 12);
  });

  test('flush always writes cookies', () async {
    final persistence = create();
    await persistence.flush();
    await persistence.flush();
    expect(flushCount, 2);
  });

  test('concurrent flushes share one platform call', () async {
    final gate = Completer<void>();
    final persistence = create(
      flush: () {
        flushCount++;
        return gate.future;
      },
    );
    final first = persistence.flush();
    final second = persistence.flush();
    final third = persistence.flushAfterPageLoad();
    expect(flushCount, 1);
    gate.complete();
    await Future.wait([first, second, third]);
    expect(flushCount, 1);
  });

  test('page-load flushes are throttled', () async {
    final persistence = create();
    await persistence.flushAfterPageLoad();
    expect(flushCount, 1);

    now = now.add(const Duration(seconds: 4));
    await persistence.flushAfterPageLoad();
    expect(flushCount, 1);

    now = now.add(const Duration(seconds: 1));
    await persistence.flushAfterPageLoad();
    expect(flushCount, 2);
  });

  test('an explicit flush is never throttled', () async {
    final persistence = create();
    await persistence.flushAfterPageLoad();
    await persistence.flush();
    expect(flushCount, 2);
  });

  test('errors are swallowed and the next flush still runs', () async {
    var calls = 0;
    final persistence = create(
      flush: () async {
        calls++;
        if (calls == 1) {
          throw Exception('disk full');
        }
      },
    );
    await expectLater(persistence.flush(), completes);
    await persistence.flush();
    expect(calls, 2);
  });

  test('a synchronous throw does not block later flushes', () async {
    var calls = 0;
    final persistence = create(
      flush: () {
        calls++;
        if (calls == 1) {
          throw Exception('sync failure');
        }
        return Future.value();
      },
    );
    await persistence.flush();
    await persistence.flush();
    expect(calls, 2);
  });

  test('a hanging flush times out instead of blocking', () async {
    final persistence = create(
      flush: () => Completer<void>().future,
      flushTimeout: const Duration(milliseconds: 50),
    );
    await expectLater(
      persistence.flush().timeout(const Duration(seconds: 2)),
      completes,
    );
  });
}
