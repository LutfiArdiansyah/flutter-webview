import '../constants/app_constants.dart';

/// Scheme and host of [url] for debug logs. Path and query are omitted
/// because they can carry OAuth codes or tokens.
String blockedHostForLog(String? url) {
  final uri = Uri.tryParse(url ?? '');
  if (uri == null || uri.host.isEmpty) {
    return uri?.scheme.isNotEmpty ?? false ? '${uri!.scheme}:' : '<invalid>';
  }
  return '${uri.scheme}://${uri.host}';
}

/// Result of parsing a list of allowlist patterns.
class AllowedHostsParseResult {
  const AllowedHostsParseResult({
    required this.patterns,
    required this.invalidEntries,
    required this.truncated,
  });

  /// Normalized, de-duplicated, valid patterns in their original order.
  final List<String> patterns;

  /// Raw entries that failed validation, in their original order.
  final List<String> invalidEntries;

  /// True when valid patterns beyond [AppConstants.maxAllowedHosts] were
  /// dropped.
  final bool truncated;
}

/// Decides which URLs the WebView may navigate to for one selected website.
///
/// Allowed when the scheme is http/https and the host is the selected
/// website's host, one of its subdomains (a leading `www.` is ignored), or
/// matches one of the website's `allowed` patterns:
/// - `host.com`        exact host
/// - `*.host.com`      host.com and every subdomain
/// - `host.com/path/`  exact host, only paths starting with `/path/`
///
/// Compiled once per website. Each check walks the host's label suffixes
/// against hash sets, so it costs O(labels in host) regardless of how many
/// patterns are configured.
class NavigationPolicy {
  NavigationPolicy._(
    this._exactHosts,
    this._wildcardBases,
    this._pathPrefixesByHost,
  );

  /// Builds the policy for [websiteUrl] and its [allowedPatterns].
  ///
  /// Invalid patterns are ignored here; callers that need to report them use
  /// [parseAllowedHosts] first. A [websiteUrl] without a host yields a policy
  /// that only honours [allowedPatterns].
  factory NavigationPolicy.forWebsite(
    String websiteUrl,
    List<String> allowedPatterns,
  ) {
    final exactHosts = <String>{};
    final wildcardBases = <String>{};
    final pathPrefixesByHost = <String, List<String>>{};

    final siteHost = _normalizeHost(Uri.tryParse(websiteUrl)?.host ?? '');
    if (siteHost.isNotEmpty) {
      final base = siteHost.startsWith('www.') && siteHost.length > 4
          ? siteHost.substring(4)
          : siteHost;
      wildcardBases.add(base);
    }

    for (final pattern in parseAllowedHosts(allowedPatterns).patterns) {
      if (pattern.startsWith('*.')) {
        wildcardBases.add(pattern.substring(2));
        continue;
      }
      final slash = pattern.indexOf('/');
      if (slash == -1) {
        exactHosts.add(pattern);
        continue;
      }
      pathPrefixesByHost
          .putIfAbsent(pattern.substring(0, slash), () => [])
          .add(pattern.substring(slash));
    }

    return NavigationPolicy._(exactHosts, wildcardBases, pathPrefixesByHost);
  }

  final Set<String> _exactHosts;
  final Set<String> _wildcardBases;
  final Map<String, List<String>> _pathPrefixesByHost;

  static const Set<String> _allowedSchemes = {'http', 'https'};
  static const Set<String> _allowedBlankUrls = {'about:blank', 'about:srcdoc'};

  /// Whether the WebView may navigate to [url].
  bool isAllowed(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    if (_allowedBlankUrls.contains(url.toLowerCase())) {
      return true;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !_allowedSchemes.contains(uri.scheme.toLowerCase())) {
      return false;
    }
    final host = _normalizeHost(uri.host);
    if (host.isEmpty) {
      return false;
    }
    if (_exactHosts.contains(host) || _matchesWildcard(host)) {
      return true;
    }
    final prefixes = _pathPrefixesByHost[host];
    if (prefixes == null) {
      return false;
    }
    final path = uri.path.isEmpty ? '/' : uri.path;
    return prefixes.any(path.startsWith);
  }

  bool _matchesWildcard(String host) {
    var suffix = host;
    while (true) {
      if (_wildcardBases.contains(suffix)) {
        return true;
      }
      final dot = suffix.indexOf('.');
      if (dot == -1) {
        return false;
      }
      suffix = suffix.substring(dot + 1);
    }
  }

  static String _normalizeHost(String host) {
    var normalized = host.trim().toLowerCase();
    while (normalized.endsWith('.')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static final RegExp _labelPattern = RegExp(
    r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$',
  );
  static final RegExp _pathPattern = RegExp(
    r"^/[A-Za-z0-9\-._~/%!$&'()*+,;=:@]*$",
  );
  static final RegExp _schemePrefix = RegExp(
    r'^https?://',
    caseSensitive: false,
  );

  /// Normalizes one pattern, or returns null when it is invalid.
  ///
  /// Accepts an optional leading `http(s)://` (stripped) and ignores
  /// surrounding whitespace. Rejects ports, queries, fragments, user info,
  /// bare `*`, and wildcards whose base has a single label (e.g. `*.com`).
  static String? normalizePattern(String raw) {
    var value = raw.trim().replaceFirst(_schemePrefix, '');
    if (value.isEmpty || value.length > AppConstants.maxAllowedHostLength) {
      return null;
    }
    if (value.contains(RegExp(r'[?#@\s\\]'))) {
      return null;
    }

    String? path;
    final slash = value.indexOf('/');
    if (slash != -1) {
      path = value.substring(slash);
      value = value.substring(0, slash);
      if (!_pathPattern.hasMatch(path)) {
        return null;
      }
    }

    var host = value.toLowerCase();
    while (host.endsWith('.')) {
      host = host.substring(0, host.length - 1);
    }

    final isWildcard = host.startsWith('*.');
    if (isWildcard) {
      if (path != null) {
        return null;
      }
      host = host.substring(2);
    }

    final labels = host.split('.');
    if (labels.any((l) => !_labelPattern.hasMatch(l))) {
      return null;
    }
    if (isWildcard && labels.length < 2) {
      return null;
    }

    if (isWildcard) {
      return '*.$host';
    }
    // A bare `/` prefix matches every path, so it is the same as the host.
    if (path == null || path == '/') {
      return host;
    }
    return '$host$path';
  }

  /// Validates, normalizes and de-duplicates [entries], keeping at most
  /// [AppConstants.maxAllowedHosts] valid patterns. Blank entries are ignored.
  static AllowedHostsParseResult parseAllowedHosts(Iterable<String> entries) {
    final patterns = <String>[];
    final seen = <String>{};
    final invalid = <String>[];
    var truncated = false;

    for (final entry in entries) {
      if (entry.trim().isEmpty) {
        continue;
      }
      final normalized = normalizePattern(entry);
      if (normalized == null) {
        invalid.add(entry.trim());
        continue;
      }
      if (!seen.add(normalized)) {
        continue;
      }
      if (patterns.length >= AppConstants.maxAllowedHosts) {
        truncated = true;
        continue;
      }
      patterns.add(normalized);
    }

    return AllowedHostsParseResult(
      patterns: List.unmodifiable(patterns),
      invalidEntries: List.unmodifiable(invalid),
      truncated: truncated,
    );
  }
}
