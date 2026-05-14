import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// SQLite local cache — theo database_schema.md
/// Dùng INSERT OR REPLACE để tránh UNIQUE constraint error
class SqliteCacheService {
  static Database? _db;
  static const String _dbName = 'viecnow_cache.db';
  static const int _dbVersion = 4;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _createEmployerReviewsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_employer_reviews (
        reviewId       TEXT PRIMARY KEY,
        revieweeId     TEXT NOT NULL,
        reviewerId     TEXT NOT NULL,
        reviewerName   TEXT,
        reviewerAvatar TEXT,
        jobId          TEXT,
        rating         REAL,
        comment        TEXT,
        createdAt      INTEGER,
        cachedAt       INTEGER
      )
    ''');
  }

  static Future<void> _createEmployerProfileTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_employer_profile (
        uid                TEXT PRIMARY KEY,
        firstName          TEXT,
        lastName           TEXT,
        email              TEXT,
        phone              TEXT,
        gender             TEXT,
        dateOfBirth        INTEGER,
        avatarUrl          TEXT,
        cccd               TEXT,
        companyName        TEXT,
        companyAddress     TEXT,
        companyLogoUrl     TEXT,
        companyPhone       TEXT,
        companyWebsite     TEXT,
        companyTaxCode     TEXT,
        companySize        TEXT,
        businessType       TEXT,
        companyDescription TEXT,
        walletBalance      REAL,
        totalSpent         REAL,
        isVerified         INTEGER,
        cachedAt           INTEGER
      )
    ''');
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

    // Table: cached_employer_profile (v2)
    await _createEmployerProfileTable(db);
    // Table: cached_employer_reviews (v3)
    await _createEmployerReviewsTable(db);
    // Table: cached_applications (v4)
    await _createApplicationsTable(db);
  }

  static Future<void> _createApplicationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_applications (
        appId           TEXT PRIMARY KEY,
        jobId           TEXT NOT NULL,
        candidateId     TEXT NOT NULL,
        employerId      TEXT NOT NULL,
        jobType         TEXT,
        jobTitle        TEXT,
        candidateName   TEXT,
        candidateAvatar TEXT,
        candidateRating REAL,
        status          TEXT,
        appliedAt       INTEGER,
        cachedAt        INTEGER
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createEmployerProfileTable(db);
    }
    if (oldVersion < 3) {
      await _createEmployerReviewsTable(db);
    }
    if (oldVersion < 4) {
      await _createApplicationsTable(db);
    }
  }

  // ─── Applications cache ──────────────────────────────────

  static Future<void> upsertApplication({
    required String appId,
    required String jobId,
    required String candidateId,
    required String employerId,
    String? jobType,
    String? jobTitle,
    String? candidateName,
    String? candidateAvatar,
    double? candidateRating,
    String? status,
    int? appliedAt,
  }) async {
    final db = await database;
    await db.rawInsert(
      '''INSERT OR REPLACE INTO cached_applications
         (appId, jobId, candidateId, employerId, jobType, jobTitle,
          candidateName, candidateAvatar, candidateRating, status, appliedAt, cachedAt)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        appId, jobId, candidateId, employerId, jobType, jobTitle,
        candidateName, candidateAvatar, candidateRating, status,
        appliedAt, DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  static Future<List<Map<String, dynamic>>> getCachedApplications({
    required String employerId,
    String? jobType,
  }) async {
    final db = await database;
    if (jobType != null) {
      return db.query(
        'cached_applications',
        where: 'employerId = ? AND jobType = ?',
        whereArgs: [employerId, jobType],
        orderBy: 'appliedAt DESC',
      );
    }
    return db.query(
      'cached_applications',
      where: 'employerId = ?',
      whereArgs: [employerId],
      orderBy: 'appliedAt DESC',
    );
  }

  static Future<void> clearApplications(String employerId) async {
    final db = await database;
    await db.delete(
      'cached_applications',
      where: 'employerId = ?',
      whereArgs: [employerId],
    );
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

  // ─── Employer Profile ────────────────────────────────────

  static Future<void> upsertEmployerProfile(Map<String, dynamic> m) async {
    final db = await database;
    await db.rawInsert(
      '''INSERT OR REPLACE INTO cached_employer_profile
         (uid, firstName, lastName, email, phone, gender, dateOfBirth, avatarUrl,
          cccd, companyName, companyAddress, companyLogoUrl, companyPhone,
          companyWebsite, companyTaxCode, companySize, businessType,
          companyDescription, walletBalance, totalSpent, isVerified, cachedAt)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        m['uid'], m['firstName'], m['lastName'], m['email'], m['phone'],
        m['gender'], m['dateOfBirth'], m['avatarUrl'], m['cccd'],
        m['companyName'], m['companyAddress'], m['companyLogoUrl'],
        m['companyPhone'], m['companyWebsite'], m['companyTaxCode'],
        m['companySize'], m['businessType'], m['companyDescription'],
        m['walletBalance'] ?? 0.0, m['totalSpent'] ?? 0.0,
        (m['isVerified'] == true) ? 1 : 0,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  static Future<Map<String, dynamic>?> getCachedEmployerProfile(String uid) async {
    final db = await database;
    final rows = await db.query(
      'cached_employer_profile',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> clearEmployerProfile(String uid) async {
    final db = await database;
    await db.delete('cached_employer_profile', where: 'uid = ?', whereArgs: [uid]);
  }

  // ─── Employer Reviews ────────────────────────────────────

  static Future<void> upsertEmployerReview(Map<String, dynamic> m) async {
    final db = await database;
    await db.rawInsert(
      '''INSERT OR REPLACE INTO cached_employer_reviews
         (reviewId, revieweeId, reviewerId, reviewerName, reviewerAvatar,
          jobId, rating, comment, createdAt, cachedAt)
         VALUES (?,?,?,?,?,?,?,?,?,?)''',
      [
        m['reviewId'], m['revieweeId'], m['reviewerId'],
        m['reviewerName'], m['reviewerAvatar'],
        m['jobId'], m['rating'], m['comment'],
        m['createdAt'], m['cachedAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  static Future<List<Map<String, dynamic>>> getCachedEmployerReviews(
      String revieweeId) async {
    final db = await database;
    return db.query(
      'cached_employer_reviews',
      where: 'revieweeId = ?',
      whereArgs: [revieweeId],
      orderBy: 'createdAt DESC',
    );
  }

  static Future<void> clearEmployerReviews(String revieweeId) async {
    final db = await database;
    await db.delete(
      'cached_employer_reviews',
      where: 'revieweeId = ?',
      whereArgs: [revieweeId],
    );
  }
}

