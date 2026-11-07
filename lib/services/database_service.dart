import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/webview_config.dart';

/// Local SQLite Database Service - Singleton
class DatabaseService {
  factory DatabaseService() => _instance;

  DatabaseService._internal();
  static final DatabaseService _instance = DatabaseService._internal();

  /// Current schema version.
  /// v1: initial schema. v2: `allowed_hosts` (JSON list, nullable).
  static const int schemaVersion = 2;

  Database? _database;

  /// Get database instance (lazily initialized)
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  /// Replaces the lazily opened database (tests only).
  @visibleForTesting
  // ignore: use_setters_to_change_properties
  void setDatabaseForTesting(Database? db) => _database = db;

  /// Initialize SQLite database and create schemas
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final pathString = join(dbPath, 'webspace.db');

    return openDatabase(
      pathString,
      version: schemaVersion,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }

  /// Creates the latest schema on a fresh install.
  @visibleForTesting
  static Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE websites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        website_name TEXT NOT NULL,
        webview_url TEXT NOT NULL,
        version TEXT,
        is_custom INTEGER NOT NULL DEFAULT 0,
        allowed_hosts TEXT
      )
    ''');
  }

  /// Migrates older schemas without touching existing rows.
  @visibleForTesting
  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // NULL marks rows saved before allowlists existed; see
      // needsAllowlistResync.
      await db.execute('ALTER TABLE websites ADD COLUMN allowed_hosts TEXT');
    }
  }

  /// Get all websites from database, ordered by ID
  Future<List<WebsiteConfig>> getWebsites() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'websites',
        orderBy: 'id ASC',
      );
      return List.generate(maps.length, (i) => WebsiteConfig.fromMap(maps[i]));
    } on Exception {
      return [];
    }
  }

  /// Whether default (remote) websites were stored before allowlists
  /// existed and should be re-synced once to pick up their `allowed` hosts.
  Future<bool> needsAllowlistResync() async {
    final db = await database;
    final rows = await db.query(
      'websites',
      columns: ['id'],
      where: 'is_custom = ? AND allowed_hosts IS NULL',
      whereArgs: [0],
      limit: 1,
    );
    return rows.isNotEmpty;
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
    return db.delete('websites', where: 'id = ?', whereArgs: [id]);
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
      await txn.delete('websites', where: 'is_custom = ?', whereArgs: [0]);

      // 2. Insert new ones
      for (final site in remoteWebsites) {
        await txn.insert(
          'websites',
          WebsiteConfig(
            websiteName: site.websiteName,
            webviewUrl: site.webviewUrl,
            version: site.version,
            isCustom: false,
            allowedHosts: site.allowedHosts,
          ).toMap(),
        );
      }
    });
  }
}
