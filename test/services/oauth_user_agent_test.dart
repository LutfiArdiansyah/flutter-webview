import 'package:flutter_test/flutter_test.dart';
import 'package:webspace/services/oauth_user_agent.dart';

void main() {
  const webViewUa =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/AP2A; wv) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
      'Chrome/131.0.6778.135 Mobile Safari/537.36';
  const browserUa =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/AP2A) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.6778.135 Mobile Safari/537.36';

  group('OAuthUserAgent.toBrowserUserAgent', () {
    test('removes the WebView markers and keeps the Chrome version', () {
      expect(OAuthUserAgent.toBrowserUserAgent(webViewUa), browserUa);
    });

    test('leaves a UA without WebView markers unchanged', () {
      expect(OAuthUserAgent.toBrowserUserAgent(browserUa), browserUa);
    });

    test('handles an empty UA', () {
      expect(OAuthUserAgent.toBrowserUserAgent(''), '');
    });
  });

  group('OAuthUserAgent.isGoogleAccountUrl', () {
    test('matches Google account hosts over https', () {
      for (final url in [
        'https://accounts.google.com/o/oauth2/v2/auth?client_id=x',
        'https://ACCOUNTS.GOOGLE.COM/',
        'https://accounts.google.com./signin',
        'https://accounts.google.co.id/accounts/SetSID',
        'https://accounts.google.de/',
        'https://accounts.google.com.br/',
        'https://accounts.youtube.com/accounts/SetSID',
        'https://gds.google.com/web/chip',
      ]) {
        expect(OAuthUserAgent.isGoogleAccountUrl(url), isTrue, reason: url);
      }
    });

    test('rejects other hosts, lookalikes and plain http', () {
      for (final url in [
        null,
        '',
        'http://accounts.google.com/',
        'https://www.google.com/recaptcha/',
        'https://accounts.google.com.evil.com/',
        'https://evil.accounts.google.com/',
        'https://accounts.google.evil/',
        'https://accounts.google.com@evil.com/',
        'https://myaccount.google.com/',
        'about:blank',
      ]) {
        expect(OAuthUserAgent.isGoogleAccountUrl(url), isFalse, reason: url);
      }
    });
  });

  group('OAuthUserAgent.userAgentFor', () {
    test('uses the browser UA only on Google account hosts', () {
      expect(
        OAuthUserAgent.userAgentFor('https://accounts.google.com/', webViewUa),
        browserUa,
      );
      expect(
        OAuthUserAgent.userAgentFor('https://site.example/cb', webViewUa),
        webViewUa,
      );
      expect(OAuthUserAgent.userAgentFor(null, webViewUa), webViewUa);
    });
  });
}
