import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/webview_config.dart';

/// Local SQLite Database Service - Singleton
class DatabaseService {
  factory DatabaseService() => _instance;

  DatabaseService._internal();
  static final DatabaseService _instance = DatabaseService._internal();

  Database? _database;

  /// Get database instance (lazily initialized)
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize SQLite database and create schemas
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final pathString = join(dbPath, 'webspace.db');

    return openDatabase(
      pathString,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE websites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            website_name TEXT NOT NULL,
            webview_url TEXT NOT NULL,
            version TEXT,
            is_custom INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  /// Get all websites from database, ordered by ID
  Future<List<WebsiteConfig>> getWebsites() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps =
          await db.query('websites', orderBy: 'id ASC');
      return List.generate(maps.length, (i) => WebsiteConfig.fromMap(maps[i]));
    } on Exception {
      return [];
    }
  }

  /// Insert a website config
  Future<int> insertWebsite(WebsiteConfig config) async {
    final db = await database;
    return db.insert(
      'websites',
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing custom website config
  Future<int> updateWebsite(WebsiteConfig config) async {
    if (config.id == null) {
      return 0;
    }
    final db = await database;
    return db.update(
      'websites',
      config.toMap(),
      where: 'id = ?',
      whereArgs: [config.id],
    );
  }

  /// Delete a website config by ID
  Future<int> deleteWebsite(int id) async {
    final db = await database;
    return db.delete(
      'websites',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Synchronize default websites fetched from the remote JSON configuration.
  /// This operation runs atomically within a transaction:
  /// 1. Deletes all current default websites (is_custom = 0).
  /// 2. Inserts all the newly fetched remote websites with is_custom = 0.
  /// Custom user-created websites (is_custom = 1) are preserved.
  Future<void> syncDefaultWebsites(List<WebsiteConfig> remoteWebsites) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Delete all current default website records
      await txn.delete(
        'websites',
        where: 'is_custom = ?',
        whereArgs: [0],
      );

      // 2. Insert new ones
      for (final site in remoteWebsites) {
        await txn.insert(
          'websites',
          WebsiteConfig(
            websiteName: site.websiteName,
            webviewUrl: site.webviewUrl,
            version: site.version,
            isCustom: false,
          ).toMap(),
        );
      }
    });
  }
}
