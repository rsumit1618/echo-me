import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class FQLiteService {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'echo_me.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE contacts(
            id TEXT PRIMARY KEY,
            displayName TEXT NOT NULL,
            normalizedPhone TEXT NOT NULL UNIQUE,
            registeredUserId TEXT,
            canCall INTEGER NOT NULL,
            syncedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages(
            id TEXT PRIMARY KEY,
            chatId TEXT NOT NULL,
            senderId TEXT NOT NULL,
            text TEXT,
            imageUrls TEXT NOT NULL,
            type TEXT NOT NULL,
            state TEXT NOT NULL,
            createdAt INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> upsertContact(Map<String, Object?> contact) async {
    final db = await database;
    await db.insert(
      'contacts',
      contact,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> readContacts() async {
    final db = await database;
    return db.query('contacts', orderBy: 'displayName COLLATE NOCASE ASC');
  }

  Future<void> cacheMessage(Map<String, Object?> message) async {
    final db = await database;
    await db.insert(
      'messages',
      message,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('contacts');
  }
}
