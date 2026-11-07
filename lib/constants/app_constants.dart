/// Application-wide constants
class AppConstants {
  /// URL to fetch WebView configuration from
  static const String jsonUrl =
      'https://raw.githubusercontent.com/LutfiArdiansyah/urlwebview-anime/refs/heads/main/url.json';

  /// HTTP request timeout in seconds
  static const int requestTimeoutSeconds = 10;

  /// App title
  static const String appTitle = 'WebSpace';

  /// App name shown in selection dialog
  static const String appSelectionTitle = 'Pilih Website';

  /// Selection dialog action label
  static const String openButtonLabel = 'Masuk';

  /// Empty state for website selection
  static const String noWebsiteAvailableMessage =
      'Tidak ada website yang tersedia.';

  /// Error message for timeout
  static const String timeoutErrorMessage =
      'Connection timeout. Please check your internet connection.';

  /// Error message for no internet
  static const String noInternetErrorMessage =
      'No internet connection. Please check your network.';

  /// Error message for network error
  static const String networkErrorMessage = 'Network error. Please try again.';

  /// Error message for invalid JSON
  static const String invalidJsonErrorMessage =
      'Failed to parse configuration. Please try again.';

  /// Error message for invalid URL
  static const String invalidUrlErrorMessage = 'Invalid URL configuration.';

  /// Generic error message
  static const String genericErrorMessage =
      'Something went wrong. Please try again.';

  /// Maximum number of `allowed` patterns kept per website.
  static const int maxAllowedHosts = 100;

  /// Maximum length of one `allowed` pattern (DNS name limit).
  static const int maxAllowedHostLength = 253;

  /// Hosts needed for Google sign-in and common captchas. Only used to
  /// pre-fill the allowlist input; never allowed automatically.
  static const List<String> googleAndCaptchaHosts = [
    'accounts.google.com',
    'accounts.google.co.id',
    'accounts.youtube.com',
    'gds.google.com',
    'challenges.cloudflare.com',
    'www.google.com/recaptcha/',
    'recaptcha.net',
    '*.recaptcha.net',
    '*.hcaptcha.com',
  ];

  /// Allowlist input label
  static const String allowedHostsLabel =
      'Host yang diizinkan (satu per baris)';

  /// Allowlist input hint
  static const String allowedHostsHint =
      '*.example.com\naccounts.google.com\nwww.google.com/recaptcha/';

  /// Allowlist input helper
  static const String allowedHostsHelper =
      'Opsional. Host lain di luar website ini yang boleh dibuka.';

  /// Button that fills the Google sign-in and captcha hosts
  static const String fillGoogleAndCaptchaLabel = 'Isi Google & Captcha';

  /// Popup close button tooltip
  static const String closePopupTooltip = 'Tutup';
}
