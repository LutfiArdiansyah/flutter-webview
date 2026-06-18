/// Model for a website entry in the remote configuration
class WebsiteConfig {
  /// The display name for the website
  final String websiteName;

  /// The URL to be displayed in WebView
  final String webviewUrl;

  /// Configuration version
  final String? version;

  WebsiteConfig({
    required this.websiteName,
    required this.webviewUrl,
    this.version,
  });

  /// Parse WebsiteConfig from JSON response
  factory WebsiteConfig.fromJson(Map<String, dynamic> json) {
    final name = json['website_name'] as String?;
    final url = json['webview_url'] as String?;
    if (name == null || name.isEmpty) {
      throw FormatException('website_name is required in configuration');
    }

    if (url == null || url.isEmpty) {
      throw FormatException('webview_url is required in configuration');
    }

    return WebsiteConfig(
      websiteName: name,
      webviewUrl: url,
      version: json['version'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'website_name': websiteName,
      'webview_url': webviewUrl,
      'version': version,
    };
  }
}
