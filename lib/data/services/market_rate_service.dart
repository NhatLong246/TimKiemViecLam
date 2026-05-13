import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:viecnow/data/models/market_rate_model.dart';
import 'sqlite_cache_service.dart';

/// Service: MarketRateService
/// Truy vấn jobPosts (approved | active) từ Firestore → tổng hợp mặt bằng lương.
/// Cache kết quả vào SQLite để xem offline.
class MarketRateService {
  static final _db = FirebaseFirestore.instance;
  static const _cacheTable = 'market_rates_cache';
  static const _cacheMaxAgeMs = 30 * 60 * 1000; // 30 phút

  // ── Ensure SQLite table tồn tại ─────────────────────────────────────────────
  static Future<void> ensureCacheTable() async {
    final db = await SqliteCacheService.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_cacheTable (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        category      TEXT NOT NULL,
        categoryLabel TEXT NOT NULL,
        city          TEXT NOT NULL,
        district      TEXT NOT NULL,
        minSalary     REAL NOT NULL,
        maxSalary     REAL NOT NULL,
        avgSalary     REAL NOT NULL,
        salaryType    TEXT NOT NULL,
        totalActiveJobs INTEGER NOT NULL,
        totalSlots    INTEGER NOT NULL,
        demandLevel   TEXT NOT NULL,
        cachedAt      INTEGER NOT NULL,
        UNIQUE(category, city, district, salaryType)
      )
    ''');
  }

  // ── Main method: lấy danh sách mặt bằng lương ──────────────────────────────
  static Future<List<MarketRateItem>> fetchMarketRates() async {
    await ensureCacheTable();
    try {
      // Thử lấy từ Firestore trước
      final items = await _fetchFromFirestore();
      if (items.isNotEmpty) {
        await _saveToSqlite(items);
        return items;
      }
    } catch (_) {
      // Firestore thất bại → fallback sang SQLite cache
    }
    return _fetchFromSqliteCache();
  }

  // ── Query Firestore: jobPosts where status in [approved, active] ────────────
  static Future<List<MarketRateItem>> _fetchFromFirestore() async {
    // Query 2 lần vì Firestore không hỗ trợ whereIn với OR trên cùng field cùng query
    final futures = await Future.wait([
      _db
          .collection('jobPosts')
          .where('status', isEqualTo: 'approved')
          .get(),
      _db
          .collection('jobPosts')
          .where('status', isEqualTo: 'active')
          .get(),
    ]);

    final allDocs = [
      ...futures[0].docs,
      ...futures[1].docs,
    ];

    if (allDocs.isEmpty) return [];

    return _aggregate(allDocs);
  }

  // ── Tổng hợp dữ liệu theo (category + city + district + salaryType) ─────────
  static List<MarketRateItem> _aggregate(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    // key = "category|city|district|salaryType"
    final Map<String, _AggBucket> buckets = {};

    for (final doc in docs) {
      final data = doc.data();
      final category = data['category'] as String? ?? 'other';
      final salaryType = data['salaryType'] as String? ?? 'per_day';
      final salary = (data['salary'] as num?)?.toDouble() ?? 0.0;
      final slots = (data['slots'] as num?)?.toInt() ?? 0;

      final location = data['location'] as Map<String, dynamic>?;
      final city = location?['city'] as String? ?? 'Không rõ';
      final district = location?['district'] as String? ?? 'Không rõ';

      if (salary <= 0) continue;

      final key = '$category|$city|$district|$salaryType';
      final bucket = buckets.putIfAbsent(key, () => _AggBucket(
            category: category,
            city: city,
            district: district,
            salaryType: salaryType,
          ));

      bucket.salaries.add(salary);
      bucket.totalSlots += slots;
      bucket.jobCount++;
    }

    return buckets.values.map((b) => b.toItem()).toList()
      ..sort((a, b) => b.totalActiveJobs.compareTo(a.totalActiveJobs));
  }

  // ── SQLite: lưu cache ────────────────────────────────────────────────────────
  static Future<void> _saveToSqlite(List<MarketRateItem> items) async {
    final db = await SqliteCacheService.database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(_cacheTable, item.toSqlite(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ── SQLite: đọc cache (tối đa 30 phút) ─────────────────────────────────────
  static Future<List<MarketRateItem>> _fetchFromSqliteCache() async {
    final db = await SqliteCacheService.database;
    final minCachedAt =
        DateTime.now().millisecondsSinceEpoch - _cacheMaxAgeMs;
    final rows = await db.query(
      _cacheTable,
      where: 'cachedAt >= ?',
      whereArgs: [minCachedAt],
      orderBy: 'totalActiveJobs DESC',
    );
    return rows.map(MarketRateItem.fromSqlite).toList();
  }

  // ── Tìm kiếm (local filter) ──────────────────────────────────────────────────
  static List<MarketRateItem> filterItems({
    required List<MarketRateItem> items,
    required String query,
    required String category, // "all" hoặc category value
  }) {
    return items.where((item) {
      final matchCat = category == 'all' || item.category == category;
      final q = query.toLowerCase().trim();
      final matchQuery = q.isEmpty ||
          item.categoryLabel.toLowerCase().contains(q) ||
          item.city.toLowerCase().contains(q) ||
          item.district.toLowerCase().contains(q);
      return matchCat && matchQuery;
    }).toList();
  }
}

// ── Internal aggregation bucket ──────────────────────────────────────────────
class _AggBucket {
  final String category;
  final String city;
  final String district;
  final String salaryType;
  final List<double> salaries = [];
  int totalSlots = 0;
  int jobCount = 0;

  _AggBucket({
    required this.category,
    required this.city,
    required this.district,
    required this.salaryType,
  });

  MarketRateItem toItem() {
    salaries.sort();
    final min = salaries.first;
    final max = salaries.last;
    final avg = salaries.reduce((a, b) => a + b) / salaries.length;

    String demand;
    if (jobCount >= 10) {
      demand = 'high';
    } else if (jobCount >= 5) {
      demand = 'medium';
    } else {
      demand = 'low';
    }

    return MarketRateItem(
      category: category,
      categoryLabel: kCategoryLabels[category] ?? 'Khác',
      city: city,
      district: district,
      minSalary: min,
      maxSalary: max,
      avgSalary: avg,
      salaryType: salaryType,
      totalActiveJobs: jobCount,
      totalSlots: totalSlots,
      demandLevel: demand,
    );
  }
}
