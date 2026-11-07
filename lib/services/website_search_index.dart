import '../models/webview_config.dart';

/// Case-insensitive name/URL search over a website list.
///
/// Lower-cased keys are computed once per list instead of on every
/// keystroke/rebuild, so filtering costs one `contains` per field.
class WebsiteSearchIndex {
  WebsiteSearchIndex(this.websites)
    : _names = [for (final w in websites) w.websiteName.toLowerCase()],
      _urls = [for (final w in websites) w.webviewUrl.toLowerCase()];

  /// The indexed list (not copied; callers replace it rather than mutate).
  final List<WebsiteConfig> websites;
  final List<String> _names;
  final List<String> _urls;

  /// Websites whose name or URL contains [query], ignoring case, in their
  /// original order. An empty query returns every website.
  List<WebsiteConfig> filter(String query) {
    if (query.isEmpty) {
      return websites;
    }
    final needle = query.toLowerCase();
    return [
      for (var i = 0; i < websites.length; i++)
        if (_names[i].contains(needle) || _urls[i].contains(needle))
          websites[i],
    ];
  }
}

/// Up to this many items the selection list shrink-wraps so a short list
/// keeps a compact dialog. Every item is at least ~84 px tall (40 px icon +
/// 32 px padding + 12 px margin), so beyond this count the list always
/// exceeds the dialog's 600 px height cap and a lazily built list looks the
/// same while only building visible rows.
const int maxShrinkWrappedListItems = 20;

/// Whether a list of [itemCount] items should shrink-wrap.
bool shouldShrinkWrapList(int itemCount) =>
    itemCount <= maxShrinkWrappedListItems;
