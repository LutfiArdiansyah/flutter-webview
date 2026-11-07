/// User-Agent handling for Google sign-in pages inside the WebView.
///
/// Google rejects OAuth in embedded WebViews (`403 disallowed_useragent`)
/// based on the WebView markers in the User-Agent. While the WebView is on a
/// Google account host we present the same UA without those markers, and
/// restore the default UA everywhere else.
///
/// This works around a Google policy and may stop working at any time.
class OAuthUserAgent {
  const OAuthUserAgent._();

  static const Set<String> _googleAccountHosts = {
    'accounts.google.com',
    'accounts.youtube.com',
    'gds.google.com',
  };

  /// `accounts.google.<cc>`, `accounts.google.co.<cc>`,
  /// `accounts.google.com.<cc>`: used by Google to set sign-in cookies on
  /// country domains.
  static final RegExp _googleCountryAccountsHost = RegExp(
    r'^accounts\.google\.(?:[a-z]{2}|co\.[a-z]{2}|com\.[a-z]{2})$',
  );

  static final RegExp _webViewToken = RegExp(r';\s*wv\)');
  static final RegExp _versionToken = RegExp(r'Version/\d+(?:\.\d+)*\s+');

  /// Whether [url] points to a Google account (sign-in) host.
  static bool isGoogleAccountUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.toLowerCase() != 'https') {
      return false;
    }
    var host = uri.host.toLowerCase();
    while (host.endsWith('.')) {
      host = host.substring(0, host.length - 1);
    }
    return _googleAccountHosts.contains(host) ||
        _googleCountryAccountsHost.hasMatch(host);
  }

  /// Returns [defaultUserAgent] without the Android WebView markers
  /// (`; wv` and `Version/x.y`), so it reads like regular Chrome. The Chrome
  /// version is kept from the device, never hardcoded.
  static String toBrowserUserAgent(String defaultUserAgent) => defaultUserAgent
      .replaceFirst(_webViewToken, ')')
      .replaceFirst(_versionToken, '');

  /// The User-Agent the WebView should use while loading [url].
  static String userAgentFor(String? url, String defaultUserAgent) =>
      isGoogleAccountUrl(url)
      ? toBrowserUserAgent(defaultUserAgent)
      : defaultUserAgent;
}
