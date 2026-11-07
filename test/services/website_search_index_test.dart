import 'package:flutter_test/flutter_test.dart';
import 'package:webspace/models/webview_config.dart';
import 'package:webspace/services/website_search_index.dart';

void main() {
  final sites = [
    WebsiteConfig(websiteName: 'Film', webviewUrl: 'https://tv12.LK21.cc'),
    WebsiteConfig(websiteName: 'Anime', webviewUrl: 'https://v2.sameh.how'),
    WebsiteConfig(websiteName: 'Film 2', webviewUrl: 'https://auberge.com'),
  ];

  /// Reference: the filter the screen used before the index existed.
  List<WebsiteConfig> legacyFilter(List<WebsiteConfig> list, String q) =>
      list.where((w) {
        final query = q.toLowerCase();
        return w.websiteName.toLowerCase().contains(query) ||
            w.webviewUrl.toLowerCase().contains(query);
      }).toList();

  group('WebsiteSearchIndex', () {
    final index = WebsiteSearchIndex(sites);

    test('empty query returns every website in order', () {
      expect(index.filter(''), sites);
    });

    test('matches name or URL case-insensitively, keeping order', () {
      expect(index.filter('FILM'), [sites[0], sites[2]]);
      expect(index.filter('lk21'), [sites[0]]);
      expect(index.filter('https://'), sites);
      expect(index.filter('nothing'), isEmpty);
    });

    test('behaves exactly like the previous filter', () {
      for (final q in ['', 'f', 'Film 2', 'AN', '.com', ' ', 'x', 'HOW']) {
        expect(index.filter(q), legacyFilter(sites, q), reason: q);
      }
    });

    test('handles an empty list', () {
      expect(WebsiteSearchIndex(const []).filter('a'), isEmpty);
    });

    test('stays correct for large lists', () {
      final many = [
        for (var i = 0; i < 5000; i++)
          WebsiteConfig(websiteName: 'Site $i', webviewUrl: 'https://s$i.com'),
      ];
      final big = WebsiteSearchIndex(many);
      expect(big.filter('site 4999'), [many.last]);
      expect(big.filter('S12'), legacyFilter(many, 'S12'));
    });
  });

  group('shouldShrinkWrapList', () {
    test('shrink-wraps short lists only', () {
      expect(shouldShrinkWrapList(0), isTrue);
      expect(shouldShrinkWrapList(maxShrinkWrappedListItems), isTrue);
      expect(shouldShrinkWrapList(maxShrinkWrappedListItems + 1), isFalse);
    });
  });
}
