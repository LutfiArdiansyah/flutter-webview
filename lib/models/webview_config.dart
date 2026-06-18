/// Model for WebView configuration
class WebViewConfig {
  /// The URL to be displayed in WebView
  final String webviewUrl;

  /// Configuration version
  final String? version;

  WebViewConfig({
    required this.webviewUrl,
    this.version,
  });

  /// Parse WebViewConfig from JSON response
  factory WebViewConfig.fromJson(Map<String, dynamic> json) {
    final url = json['webview_url'] as String?;
    if (url == null || url.isEmpty) {
      throw FormatException('webview_url is required in configuration');
    }

    return WebViewConfig(
      webviewUrl: url,
      version: json['version'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'webview_url': webviewUrl,
      'version': version,
    };
  }
}
