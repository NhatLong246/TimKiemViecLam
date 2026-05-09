import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// SQLite local cache — theo database_schema.md
/// Dùng INSERT OR REPLACE để tránh UNIQUE constraint error
class SqliteCacheService {
  static Database? _db;
  static const String _dbName = 'viecnow_cache.db';
  static const int _dbVersion = 1;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Table: cached_profile — PK: uid
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_profile (
        uid       TEXT PRIMARY KEY,
        role      TEXT,
        firstName TEXT,
        lastName  TEXT,
        email     TEXT,
        phone     TEXT,
        avatarUrl TEXT,
        cachedAt  INTEGER
      )
    ''');

    // Table: cached_jobs — PK: jobId
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_jobs (
        jobId      TEXT PRIMARY KEY,
        employerId TEXT NOT NULL,
        title      TEXT NOT NULL,
        category   TEXT,
        jobType    TEXT,
        location   TEXT,
        salary     REAL,
        salaryType TEXT,
        slots      INTEGER,
        startDate  INTEGER,
        status     TEXT,
        cachedAt   INTEGER
      )
    ''');

    // Table: saved_jobs — PK: jobId (UNIQUE)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_jobs (
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        jobId   TEXT NOT NULL UNIQUE,
        savedAt INTEGER
      )
    ''');
  }

  // ─── Profile ────────────────────────────────────────────

  /// Cache hoặc update profile (INSERT OR REPLACE)
  static Future<void> upsertProfile({
    required String uid,
    required String role,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    String? avatarUrl,
  }) async {
    final db = await database;
    await db.rawInsert(
      '''INSERT OR REPLACE INTO cached_profile
         (uid, role, firstName, lastName, email, phone, avatarUrl, cachedAt)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      [uid, role, firstName, lastName, email, phone, avatarUrl, DateTime.now().millisecondsSinceEpoch],
    );
  }

  /// Lấy profile từ cache
  static Future<Map<String, dynamic>?> getCachedProfile(String uid) async {
    final db = await database;
    final rows = await db.query(
      'cached_profile',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Xóa profile khi logout
  static Future<void> clearProfile(String uid) async {
    final db = await database;
    await db.delete('cached_profile', where: 'uid = ?', whereArgs: [uid]);
  }

  // ─── Jobs ───────────────────────────────────────────────

  /// Cache danh sách job (INSERT OR REPLACE)
  static Future<void> upsertJob(Map<String, dynamic> jobMap) async {
    final db = await database;
    await db.rawInsert(
      '''INSERT OR REPLACE INTO cached_jobs
         (jobId, employerId, title, category, jobType, location, salary, salaryType, slots, startDate, status, cachedAt)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        jobMap['jobId'],
        jobMap['employerId'],
        jobMap['title'],
        jobMap['category'],
        jobMap['jobType'],
        jobMap['location'],
        jobMap['salary'],
        jobMap['salaryType'],
        jobMap['slots'],
        jobMap['startDate'],
        jobMap['status'],
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  /// Lấy tất cả cached jobs
  static Future<List<Map<String, dynamic>>> getCachedJobs() async {
    final db = await database;
    return db.query('cached_jobs', orderBy: 'cachedAt DESC');
  }

  // ─── Saved Jobs ─────────────────────────────────────────

  static Future<void> saveJob(String jobId) async {
    final db = await database;
    await db.rawInsert(
      'INSERT OR IGNORE INTO saved_jobs (jobId, savedAt) VALUES (?, ?)',
      [jobId, DateTime.now().millisecondsSinceEpoch],
    );
  }

  static Future<void> unsaveJob(String jobId) async {
    final db = await database;
    await db.delete('saved_jobs', where: 'jobId = ?', whereArgs: [jobId]);
  }

  static Future<List<Map<String, dynamic>>> getSavedJobs() async {
    final db = await database;
    return db.query('saved_jobs', orderBy: 'savedAt DESC');
  }
}
