import 'package:flutter_test/flutter_test.dart';
import 'package:webspace/models/webview_config.dart';

void main() {
  group('WebsiteConfig.fromJson', () {
    test('parses a valid entry as a default (non-custom) website', () {
      final config = WebsiteConfig.fromJson({
        'website_name': 'Example',
        'webview_url': 'https://example.com',
        'version': '1.0',
      });

      expect(config.id, isNull);
      expect(config.websiteName, 'Example');
      expect(config.webviewUrl, 'https://example.com');
      expect(config.version, '1.0');
      expect(config.isCustom, isFalse);
    });

    test('accepts a missing version', () {
      final config = WebsiteConfig.fromJson({
        'website_name': 'Example',
        'webview_url': 'https://example.com',
      });

      expect(config.version, isNull);
    });

    for (final name in [null, '']) {
      test('rejects website_name = ${name == null ? 'null' : 'empty'}', () {
        expect(
          () => WebsiteConfig.fromJson({
            'website_name': name,
            'webview_url': 'https://example.com',
          }),
          throwsFormatException,
        );
      });
    }

    for (final url in [null, '']) {
      test('rejects webview_url = ${url == null ? 'null' : 'empty'}', () {
        expect(
          () => WebsiteConfig.fromJson({
            'website_name': 'Example',
            'webview_url': url,
          }),
          throwsFormatException,
        );
      });
    }
  });

  group('WebsiteConfig.fromJson allowed', () {
    Map<String, dynamic> entry(Object? allowed) => {
      'website_name': 'Example',
      'webview_url': 'https://example.com',
      'allowed': allowed,
    };

    test('missing allowed yields an empty list', () {
      final config = WebsiteConfig.fromJson({
        'website_name': 'Example',
        'webview_url': 'https://example.com',
      });
      expect(config.allowedHosts, isEmpty);
    });

    for (final value in [
      null,
      'accounts.google.com',
      42,
      {'a': 1},
    ]) {
      test('non-list allowed ($value) yields an empty list', () {
        expect(WebsiteConfig.fromJson(entry(value)).allowedHosts, isEmpty);
      });
    }

    test('normalizes valid entries and drops invalid/non-string ones', () {
      final config = WebsiteConfig.fromJson(
        entry([
          'Accounts.Google.com',
          42,
          null,
          '*',
          '*.lk21official.cc',
          'accounts.google.com',
        ]),
      );
      expect(config.allowedHosts, ['accounts.google.com', '*.lk21official.cc']);
    });

    test('allowedHosts is unmodifiable', () {
      final config = WebsiteConfig.fromJson(entry(['a.com']));
      expect(() => config.allowedHosts.add('b.com'), throwsUnsupportedError);
    });

    test('parseAllowedJson reports non-string entries as invalid', () {
      final result = WebsiteConfig.parseAllowedJson(['ok.com', 1, '*']);
      expect(result.patterns, ['ok.com']);
      expect(result.invalidEntries, ['*', '1']);
    });
  });

  group('WebsiteConfig map round-trip', () {
    test('preserves every field', () {
      final original = WebsiteConfig(
        id: 7,
        websiteName: 'Custom',
        webviewUrl: 'https://custom.example',
        version: '2',
        isCustom: true,
        allowedHosts: const ['*.custom.example', 'www.google.com/recaptcha/'],
      );

      final restored = WebsiteConfig.fromMap(original.toMap());

      expect(restored.id, 7);
      expect(restored.websiteName, 'Custom');
      expect(restored.webviewUrl, 'https://custom.example');
      expect(restored.version, '2');
      expect(restored.isCustom, isTrue);
      expect(restored.allowedHosts, [
        '*.custom.example',
        'www.google.com/recaptcha/',
      ]);
    });

    for (final stored in [null, '', 'not json', '{"a":1}', '[1, "*"]']) {
      test('decodes allowed_hosts=$stored as an empty list', () {
        final config = WebsiteConfig.fromMap({
          'id': 1,
          'website_name': 'Old',
          'webview_url': 'https://old.example',
          'version': null,
          'is_custom': 0,
          'allowed_hosts': stored,
        });
        expect(config.allowedHosts, isEmpty);
      });
    }

    test('reads rows without the allowed_hosts key (v1 shape)', () {
      final config = WebsiteConfig.fromMap({
        'id': 1,
        'website_name': 'Old',
        'webview_url': 'https://old.example',
        'version': null,
        'is_custom': 1,
      });
      expect(config.allowedHosts, isEmpty);
    });

    test('toMap stores an empty list as [] (not NULL)', () {
      final map = WebsiteConfig(
        websiteName: 'New',
        webviewUrl: 'https://new.example',
      ).toMap();
      expect(map['allowed_hosts'], '[]');
    });

    test('omits id when null so SQLite autoincrements it', () {
      final map = WebsiteConfig(
        websiteName: 'New',
        webviewUrl: 'https://new.example',
      ).toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['is_custom'], 0);
    });
  });
}
