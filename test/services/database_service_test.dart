import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:webspace/models/webview_config.dart';
import 'package:webspace/services/database_service.dart';

/// v1 schema exactly as shipped before allowlists existed.
Future<void> _createV1(Database db, int version) => db.execute('''
  CREATE TABLE websites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    website_name TEXT NOT NULL,
    webview_url TEXT NOT NULL,
    version TEXT,
    is_custom INTEGER NOT NULL DEFAULT 0
  )
''');

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final service = DatabaseService();

  Future<Database> openLatest(String path) => factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: DatabaseService.schemaVersion,
      onCreate: DatabaseService.onCreate,
      onUpgrade: DatabaseService.onUpgrade,
    ),
  );

  tearDown(() => service.setDatabaseForTesting(null));

  test('upgrades v1 to v2 keeping existing rows', () async {
    final dir = await factory.getDatabasesPath();
    final path = '$dir/webspace_upgrade_test.db';
    await factory.deleteDatabase(path);

    final v1 = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1, onCreate: _createV1),
    );
    await v1.insert('websites', {
      'website_name': 'Remote',
      'webview_url': 'https://remote.example',
      'version': '1.0',
      'is_custom': 0,
    });
    await v1.insert('websites', {
      'website_name': 'Mine',
      'webview_url': 'https://mine.example',
      'is_custom': 1,
    });
    await v1.close();

    final db = await openLatest(path);
    service.setDatabaseForTesting(db);

    final sites = await service.getWebsites();
    expect(sites.map((s) => s.websiteName), ['Remote', 'Mine']);
    expect(sites.map((s) => s.webviewUrl), [
      'https://remote.example',
      'https://mine.example',
    ]);
    expect(sites.every((s) => s.allowedHosts.isEmpty), isTrue);
    expect(sites[1].isCustom, isTrue);

    // Remote rows from v1 have no allowlist yet.
    expect(await service.needsAllowlistResync(), isTrue);

    await service.syncDefaultWebsites([
      WebsiteConfig(
        websiteName: 'Remote',
        webviewUrl: 'https://remote.example',
        allowedHosts: const ['accounts.google.com'],
      ),
    ]);
    expect(await service.needsAllowlistResync(), isFalse);

    final synced = await service.getWebsites();
    expect(synced.map((s) => s.websiteName), ['Mine', 'Remote']);
    expect(synced.last.allowedHosts, ['accounts.google.com']);
    expect(synced.first.isCustom, isTrue);

    await db.close();
    await factory.deleteDatabase(path);
  });

  test('fresh install stores and reads allowlists', () async {
    final db = await openLatest(inMemoryDatabasePath);
    service.setDatabaseForTesting(db);

    expect(await service.needsAllowlistResync(), isFalse);

    await service.syncDefaultWebsites([
      WebsiteConfig(websiteName: 'A', webviewUrl: 'https://a.example'),
    ]);
    // An empty allowlist is stored as [] so it never triggers a resync.
    expect(await service.needsAllowlistResync(), isFalse);

    final id = await service.insertWebsite(
      WebsiteConfig(
        websiteName: 'Custom',
        webviewUrl: 'https://c.example',
        isCustom: true,
        allowedHosts: const ['*.c.example'],
      ),
    );
    await service.updateWebsite(
      WebsiteConfig(
        id: id,
        websiteName: 'Custom 2',
        webviewUrl: 'https://c.example',
        isCustom: true,
        allowedHosts: const ['*.c.example', 'accounts.google.com'],
      ),
    );

    final custom = (await service.getWebsites()).firstWhere((s) => s.id == id);
    expect(custom.websiteName, 'Custom 2');
    expect(custom.allowedHosts, ['*.c.example', 'accounts.google.com']);

    await db.close();
  });
}
