/// Model for a website entry in the remote configuration
class WebsiteConfig {
  WebsiteConfig({
    required this.websiteName,
    required this.webviewUrl,
    this.id,
    this.version,
    this.isCustom = false,
  });

  /// Parse WebsiteConfig from JSON response
  factory WebsiteConfig.fromJson(Map<String, dynamic> json) {
    final name = json['website_name'] as String?;
    final url = json['webview_url'] as String?;
    if (name == null || name.isEmpty) {
      throw const FormatException('website_name is required in configuration');
    }

    if (url == null || url.isEmpty) {
      throw const FormatException('webview_url is required in configuration');
    }

    return WebsiteConfig(
      websiteName: name,
      webviewUrl: url,
      version: json['version'] as String?,
      isCustom: false,
    );
  }

  /// Parse WebsiteConfig from SQLite Map
  factory WebsiteConfig.fromMap(Map<String, dynamic> map) => WebsiteConfig(
        id: map['id'] as int?,
        websiteName: map['website_name'] as String,
        webviewUrl: map['webview_url'] as String,
        version: map['version'] as String?,
        isCustom: (map['is_custom'] as int) == 1,
      );

  /// The unique ID for database records
  final int? id;

  /// The display name for the website
  final String websiteName;

  /// The URL to be displayed in WebView
  final String webviewUrl;

  /// Configuration version
  final String? version;

  /// Flag to determine if this is a user-added website
  final bool isCustom;

  /// Convert to JSON (used for remote structures if needed)
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'website_name': websiteName,
        'webview_url': webviewUrl,
        'version': version,
        'is_custom': isCustom ? 1 : 0,
      };

  /// Convert to map for SQLite insertion/update
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'website_name': websiteName,
        'webview_url': webviewUrl,
        'version': version,
        'is_custom': isCustom ? 1 : 0,
      };
}
