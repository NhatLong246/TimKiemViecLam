import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/employer_stats_model.dart';

enum EmployerBucketInterval { hour, day, week, month }

class EmployerStatsService {
  final _db = FirebaseFirestore.instance;

  // ─── Fetch summary + chart data ─────────────────────────────────────────

  /// Lấy tổng hợp thống kê trong khoảng [start, end]
  Future<EmployerStatsSummary> fetchSummary({
    required String employerId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final startTs = Timestamp.fromDate(start);
      final endTs = Timestamp.fromDate(end.add(const Duration(days: 1)));

      // --- jobPosts ---
      final jobsSnap = await _db
          .collection('jobPosts')
          .where('employerId', isEqualTo: employerId)
          .get();

      int approvedPosts = 0;
      int cancelledPosts = 0;
      int totalHired = 0;

      for (final doc in jobsSnap.docs) {
        final data = doc.data();
        final ts = (data['createdAt'] as Timestamp?)?.toDate();
        if (ts == null || ts.isBefore(start) || ts.isAfter(end)) continue;

        final status = data['status'] as String? ?? '';
        final filled = (data['filledSlots'] as num?)?.toInt() ?? 0;

        if (status == 'approved' || status == 'active' || status == 'closed') {
          approvedPosts++;
          totalHired += filled;
        }
        if (status == 'rejected' || status == 'closed') {
          cancelledPosts++;
        }
      }

      // --- transactions ---
      final txnSnap = await _db
          .collection('walletTransactions')
          .where('userId', isEqualTo: employerId)
          .where('status', isEqualTo: 'completed')
          .get();

      double totalSpent = 0.0;
      double totalDeposited = 0.0;

      for (final doc in txnSnap.docs) {
        final data = doc.data();
        final ts = (data['createdAt'] as Timestamp?)?.toDate();
        if (ts == null || ts.isBefore(start) || ts.isAfter(end)) continue;

        final type = data['type'] as String? ?? '';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

        if (type == 'payment' || type == 'hold' || type == 'job_deposit_hold') {
          totalSpent += amount;
        } else if (type == 'deposit') {
          totalDeposited += amount;
        }
      }

      return EmployerStatsSummary(
        approvedPosts: approvedPosts,
        cancelledPosts: cancelledPosts,
        totalHired: totalHired,
        totalSpent: totalSpent,
        totalDeposited: totalDeposited,
      );
    } catch (e) {
      print('[EmployerStatsService] fetchSummary error: $e');
      return EmployerStatsSummary.empty();
    }
  }



  EmployerBucketInterval _getInterval(DateTime start, DateTime end) {
    final diffDays = end.difference(start).inDays;
    if (diffDays <= 2) return EmployerBucketInterval.hour;
    if (diffDays <= 31) return EmployerBucketInterval.day;
    if (diffDays <= 120) return EmployerBucketInterval.week;
    return EmployerBucketInterval.month;
  }

  /// Lấy dữ liệu biểu đồ, nhóm theo [period] (được chuyển đổi thành interval động)
  Future<List<EmployerChartPoint>> fetchChartData({
    required String employerId,
    required DateTime start,
    required DateTime end,
    required StatsPeriod period,
  }) async {
    try {
      final startTs = Timestamp.fromDate(start);
      final endTs = Timestamp.fromDate(end.add(const Duration(days: 1)));

      // Fetch jobs
      final jobsSnap = await _db
          .collection('jobPosts')
          .where('employerId', isEqualTo: employerId)
          .get();

      // Fetch transactions
      final txnSnap = await _db
          .collection('walletTransactions')
          .where('userId', isEqualTo: employerId)
          .where('status', isEqualTo: 'completed')
          .get();

      // Build bucket map based on dynamic interval
      final interval = _getInterval(start, end);
      final buckets = _buildBuckets(start, end, interval);

      for (final doc in jobsSnap.docs) {
        final data = doc.data();
        final ts = (data['createdAt'] as Timestamp?)?.toDate();
        if (ts == null || ts.isBefore(start) || ts.isAfter(end)) continue;
        final key = _bucketKey(ts, interval);
        if (buckets.containsKey(key)) {
          final status = data['status'] as String? ?? '';
          final filled = (data['filledSlots'] as num?)?.toInt() ?? 0;
          buckets[key]!.posts++;
          if (status == 'approved' ||
              status == 'active' ||
              status == 'closed') {
            buckets[key]!.hired += filled;
          }
        }
      }

      for (final doc in txnSnap.docs) {
        final data = doc.data();
        final ts = (data['createdAt'] as Timestamp?)?.toDate();
        if (ts == null || ts.isBefore(start) || ts.isAfter(end)) continue;
        final key = _bucketKey(ts, interval);
        if (buckets.containsKey(key)) {
          final type = data['type'] as String? ?? '';
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          if (type == 'payment' ||
              type == 'hold' ||
              type == 'job_deposit_hold') {
            buckets[key]!.spent += amount;
          } else if (type == 'deposit') {
            buckets[key]!.deposited += amount;
          }
        }
      }

      return buckets.entries
          .map(
            (e) => EmployerChartPoint(
              label: _bucketLabel(e.key, interval),
              spent: e.value.spent,
              deposited: e.value.deposited,
              hired: e.value.hired,
              posts: e.value.posts,
            ),
          )
          .toList();
    } catch (e) {
      print('[EmployerStatsService] fetchChartData error: $e');
      return [];
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  Map<String, _Bucket> _buildBuckets(
    DateTime start,
    DateTime end,
    EmployerBucketInterval interval,
  ) {
    final map = <String, _Bucket>{};
    DateTime cursor = _normalize(start, interval);
    final limit = end.add(const Duration(days: 1));
    while (cursor.isBefore(limit)) {
      final key = _bucketKey(cursor, interval);
      if (!map.containsKey(key)) {
        map[key] = _Bucket();
      }
      cursor = _advance(cursor, interval);
    }
    return map;
  }

  DateTime _normalize(DateTime dt, EmployerBucketInterval interval) {
    switch (interval) {
      case EmployerBucketInterval.hour:
        return DateTime(dt.year, dt.month, dt.day, dt.hour);
      case EmployerBucketInterval.day:
      case EmployerBucketInterval.week:
        return DateTime(dt.year, dt.month, dt.day);
      case EmployerBucketInterval.month:
        return DateTime(dt.year, dt.month);
    }
  }

  DateTime _advance(DateTime dt, EmployerBucketInterval interval) {
    switch (interval) {
      case EmployerBucketInterval.hour:
        return dt.add(const Duration(hours: 1));
      case EmployerBucketInterval.day:
        return dt.add(const Duration(days: 1));
      case EmployerBucketInterval.week:
        return dt.add(const Duration(days: 7));
      case EmployerBucketInterval.month:
        return DateTime(dt.year, dt.month + 1);
    }
  }

  String _bucketKey(DateTime dt, EmployerBucketInterval interval) {
    switch (interval) {
      case EmployerBucketInterval.hour:
        return DateFormat('yyyy-MM-dd HH:mm').format(dt);
      case EmployerBucketInterval.day:
        return DateFormat('yyyy-MM-dd').format(dt);
      case EmployerBucketInterval.week:
        final w = ((dt.day - 1) / 7).floor() + 1;
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-W$w';
      case EmployerBucketInterval.month:
        return DateFormat('yyyy-MM').format(dt);
    }
  }

  String _bucketLabel(String key, EmployerBucketInterval interval) {
    // We parse the key back or format it directly. 
    // Wait, the key itself is sortable string. Let's just create the label during map creation instead.
    // Actually, in fetchChartData we iterate buckets.entries, the order of entries is preserved in Dart!
    try {
      switch (interval) {
        case EmployerBucketInterval.hour:
          final parts = key.split(' ');
          return parts[1]; // HH:mm
        case EmployerBucketInterval.day:
          final parts = key.split('-');
          return '${parts[2]}/${parts[1]}'; // dd/MM
        case EmployerBucketInterval.week:
          final parts = key.split('-');
          return 'Tuần ${parts[2].replaceAll('W', '')} T${int.parse(parts[1])}';
        case EmployerBucketInterval.month:
          final parts = key.split('-');
          return 'T${int.parse(parts[1])}';
      }
    } catch (_) {
      return key;
    }
  }

}

class _Bucket {
  double spent = 0.0;
  double deposited = 0.0;
  int hired = 0;
  int posts = 0;
}
