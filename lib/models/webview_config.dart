import 'dart:convert';

import '../services/navigation_policy.dart';

/// Model for a website entry in the remote configuration
class WebsiteConfig {
  WebsiteConfig({
    required this.websiteName,
    required this.webviewUrl,
    this.id,
    this.version,
    this.isCustom = false,
    List<String> allowedHosts = const [],
  }) : allowedHosts = List.unmodifiable(allowedHosts);

  /// Parse WebsiteConfig from JSON response.
  ///
  /// `allowed` is optional: missing, null or non-list means no extra hosts.
  /// Non-string and invalid entries are dropped so one bad entry never
  /// rejects the whole configuration.
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
      allowedHosts: parseAllowedJson(json['allowed']).patterns,
    );
  }

  /// Parse WebsiteConfig from SQLite Map
  factory WebsiteConfig.fromMap(Map<String, dynamic> map) => WebsiteConfig(
    id: map['id'] as int?,
    websiteName: map['website_name'] as String,
    webviewUrl: map['webview_url'] as String,
    version: map['version'] as String?,
    isCustom: (map['is_custom'] as int) == 1,
    allowedHosts: decodeAllowedHosts(map['allowed_hosts'] as String?),
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

  /// Extra hosts (normalized patterns) this website may navigate to.
  final List<String> allowedHosts;

  /// Parses a raw remote `allowed` value. Non-string entries are reported
  /// as invalid.
  static AllowedHostsParseResult parseAllowedJson(Object? raw) {
    if (raw is! List) {
      return NavigationPolicy.parseAllowedHosts(const []);
    }
    final parsed = NavigationPolicy.parseAllowedHosts(raw.whereType<String>());
    final nonStrings = raw.where((e) => e is! String).map((e) => '$e');
    if (nonStrings.isEmpty) {
      return parsed;
    }
    return AllowedHostsParseResult(
      patterns: parsed.patterns,
      invalidEntries: List.unmodifiable([
        ...parsed.invalidEntries,
        ...nonStrings,
      ]),
      truncated: parsed.truncated,
    );
  }

  /// Decodes the `allowed_hosts` column. NULL or malformed data yields an
  /// empty list; stored entries are re-validated.
  static List<String> decodeAllowedHosts(String? stored) {
    if (stored == null || stored.isEmpty) {
      return const [];
    }
    try {
      return parseAllowedJson(jsonDecode(stored)).patterns;
    } on FormatException {
      return const [];
    }
  }

  /// Convert to JSON (used for remote structures if needed)
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'website_name': websiteName,
    'webview_url': webviewUrl,
    'version': version,
    'is_custom': isCustom ? 1 : 0,
    'allowed': allowedHosts,
  };

  /// Convert to map for SQLite insertion/update
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'website_name': websiteName,
    'webview_url': webviewUrl,
    'version': version,
    'is_custom': isCustom ? 1 : 0,
    'allowed_hosts': jsonEncode(allowedHosts),
  };
}
