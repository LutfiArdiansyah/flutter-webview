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
}
