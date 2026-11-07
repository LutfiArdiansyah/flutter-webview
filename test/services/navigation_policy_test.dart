import 'package:flutter_test/flutter_test.dart';
import 'package:webspace/constants/app_constants.dart';
import 'package:webspace/services/navigation_policy.dart';

void main() {
  group('NavigationPolicy.isAllowed - selected website', () {
    final policy = NavigationPolicy.forWebsite(
      'https://tv12.lk21official.cc',
      const [],
    );

    test('allows the selected host and its subdomains', () {
      expect(policy.isAllowed('https://tv12.lk21official.cc/movie/1'), isTrue);
      expect(policy.isAllowed('http://tv12.lk21official.cc'), isTrue);
      expect(policy.isAllowed('https://cdn.tv12.lk21official.cc/a.js'), isTrue);
    });

    test('blocks sibling subdomains and the parent when not allowed', () {
      expect(policy.isAllowed('https://lk21official.cc'), isFalse);
      expect(policy.isAllowed('https://tv13.lk21official.cc'), isFalse);
    });

    test('blocks other sites, lookalikes and userinfo tricks', () {
      expect(policy.isAllowed('https://ads.example.com'), isFalse);
      expect(policy.isAllowed('https://nottv12.lk21official.cc'), isFalse);
      expect(
        policy.isAllowed('https://tv12.lk21official.cc.evil.com'),
        isFalse,
      );
      expect(
        policy.isAllowed('https://tv12.lk21official.cc@evil.com/'),
        isFalse,
      );
    });

    test('is case-insensitive, ignores trailing dot and port', () {
      expect(policy.isAllowed('https://TV12.LK21OFFICIAL.CC/'), isTrue);
      expect(policy.isAllowed('https://tv12.lk21official.cc./x'), isTrue);
      expect(policy.isAllowed('https://tv12.lk21official.cc:8443/x'), isTrue);
    });

    test('blocks non-http schemes, empty and malformed URLs', () {
      for (final url in [
        null,
        '',
        'intent://scan/#Intent;scheme=zxing;end',
        'mailto:a@tv12.lk21official.cc',
        'javascript:alert(1)',
        'data:text/html,hi',
        'file:///etc/hosts',
        'https://',
        'http://[::1',
      ]) {
        expect(policy.isAllowed(url), isFalse, reason: '$url');
      }
    });

    test('allows about:blank and about:srcdoc', () {
      expect(policy.isAllowed('about:blank'), isTrue);
      expect(policy.isAllowed('ABOUT:BLANK'), isTrue);
      expect(policy.isAllowed('about:srcdoc'), isTrue);
    });
  });

  group('NavigationPolicy.isAllowed - www handling', () {
    test('www site allows the bare domain and its subdomains', () {
      final policy = NavigationPolicy.forWebsite(
        'https://www.example.com',
        const [],
      );
      expect(policy.isAllowed('https://example.com'), isTrue);
      expect(policy.isAllowed('https://m.example.com'), isTrue);
      expect(policy.isAllowed('https://www.example.com'), isTrue);
    });

    test('bare site allows www and other subdomains', () {
      final policy = NavigationPolicy.forWebsite(
        'https://aubergedelavenir.com',
        const [],
      );
      expect(policy.isAllowed('https://www.aubergedelavenir.com'), isTrue);
      expect(policy.isAllowed('https://m.aubergedelavenir.com'), isTrue);
      expect(policy.isAllowed('https://aubergedelavenir.co'), isFalse);
    });
  });

  group('NavigationPolicy.isAllowed - allowed patterns', () {
    final policy = NavigationPolicy.forWebsite(
      'https://tv12.lk21official.cc',
      const [
        '*.lk21official.cc',
        'accounts.google.com',
        'www.google.com/recaptcha/',
        '*.hcaptcha.com',
      ],
    );

    test('wildcard allows the base and every subdomain', () {
      expect(policy.isAllowed('https://lk21official.cc'), isTrue);
      expect(policy.isAllowed('https://tv13.lk21official.cc'), isTrue);
      expect(policy.isAllowed('https://a.b.lk21official.cc'), isTrue);
      expect(policy.isAllowed('https://xlk21official.cc'), isFalse);
    });

    test('exact host does not allow its subdomains', () {
      expect(policy.isAllowed('https://accounts.google.com/o/oauth2'), isTrue);
      expect(policy.isAllowed('https://evil.accounts.google.com'), isFalse);
      expect(policy.isAllowed('https://accounts.google.com.evil.com'), isFalse);
      expect(policy.isAllowed('https://evilgoogle.com'), isFalse);
    });

    test('path prefix only matches paths under that prefix', () {
      expect(
        policy.isAllowed('https://www.google.com/recaptcha/api2/anchor'),
        isTrue,
      );
      expect(policy.isAllowed('https://www.google.com/recaptcha/'), isTrue);
      expect(policy.isAllowed('https://www.google.com/recaptchaX'), isFalse);
      expect(policy.isAllowed('https://www.google.com/search?q=x'), isFalse);
      expect(policy.isAllowed('https://www.google.com'), isFalse);
      expect(policy.isAllowed('https://google.com/recaptcha/'), isFalse);
    });

    test('ignores invalid patterns instead of widening access', () {
      final p = NavigationPolicy.forWebsite('https://site.example', const [
        '*',
        '*.com',
        'evil.com:443',
        'a b.com',
      ]);
      expect(p.isAllowed('https://evil.com'), isFalse);
      expect(p.isAllowed('https://anything.com'), isFalse);
    });

    test('works when the website URL has no host', () {
      final p = NavigationPolicy.forWebsite('not a url', const ['ok.com']);
      expect(p.isAllowed('https://ok.com'), isTrue);
      expect(p.isAllowed('https://other.com'), isFalse);
    });
  });

  group('NavigationPolicy.normalizePattern', () {
    test('normalizes valid patterns', () {
      expect(NavigationPolicy.normalizePattern(' Example.COM '), 'example.com');
      expect(NavigationPolicy.normalizePattern('example.com.'), 'example.com');
      expect(
        NavigationPolicy.normalizePattern('https://example.com'),
        'example.com',
      );
      expect(
        NavigationPolicy.normalizePattern('HTTP://example.com/'),
        'example.com',
      );
      expect(
        NavigationPolicy.normalizePattern('*.Example.com'),
        '*.example.com',
      );
      expect(
        NavigationPolicy.normalizePattern('www.google.com/recaptcha/'),
        'www.google.com/recaptcha/',
      );
      expect(NavigationPolicy.normalizePattern('localhost'), 'localhost');
      expect(
        NavigationPolicy.normalizePattern('xn--bcher-kva.example'),
        'xn--bcher-kva.example',
      );
    });

    test('rejects invalid patterns', () {
      for (final raw in [
        '',
        '   ',
        '*',
        '*.',
        '*.com',
        '**.example.com',
        'a.*.example.com',
        '*.example.com/path',
        'example.com:8080',
        'example.com?x=1',
        'example.com#top',
        'user@example.com',
        'exa mple.com',
        '-example.com',
        'example-.com',
        'example..com',
        'ftp://example.com',
        r'example.com\path',
        'example.com/pa th',
        '${'a' * 64}.com',
        '${'a.' * 127}com',
      ]) {
        expect(NavigationPolicy.normalizePattern(raw), isNull, reason: raw);
      }
    });
  });

  group('NavigationPolicy.parseAllowedHosts', () {
    test('skips blanks, de-duplicates case-insensitively, keeps order', () {
      final result = NavigationPolicy.parseAllowedHosts([
        'b.com',
        '',
        '  ',
        'A.com',
        'B.COM',
        'https://a.com',
      ]);
      expect(result.patterns, ['b.com', 'a.com']);
      expect(result.invalidEntries, isEmpty);
      expect(result.truncated, isFalse);
    });

    test('reports invalid entries in order', () {
      final result = NavigationPolicy.parseAllowedHosts([
        'ok.com',
        '*',
        'x:1',
        'y.com',
      ]);
      expect(result.patterns, ['ok.com', 'y.com']);
      expect(result.invalidEntries, ['*', 'x:1']);
    });

    test('caps the number of patterns', () {
      final entries = [
        for (var i = 0; i < AppConstants.maxAllowedHosts + 5; i++) 'h$i.com',
      ];
      final result = NavigationPolicy.parseAllowedHosts(entries);
      expect(result.patterns, hasLength(AppConstants.maxAllowedHosts));
      expect(result.truncated, isTrue);
    });

    test('duplicates do not count towards the cap', () {
      final entries = [
        for (var i = 0; i < AppConstants.maxAllowedHosts; i++) 'h$i.com',
        'h0.com',
      ];
      final result = NavigationPolicy.parseAllowedHosts(entries);
      expect(result.truncated, isFalse);
    });

    test('accepts the standard Google and captcha list', () {
      final result = NavigationPolicy.parseAllowedHosts(
        AppConstants.googleAndCaptchaHosts,
      );
      expect(result.invalidEntries, isEmpty);
      expect(result.patterns, AppConstants.googleAndCaptchaHosts);
    });
  });
}
