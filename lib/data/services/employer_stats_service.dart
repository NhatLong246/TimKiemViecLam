import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/employer_stats_model.dart';

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
          .where('createdAt', isGreaterThanOrEqualTo: startTs)
          .where('createdAt', isLessThan: endTs)
          .get();

      int approvedPosts = 0;
      int cancelledPosts = 0;
      int totalHired = 0;

      for (final doc in jobsSnap.docs) {
        final data = doc.data();
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
          .collection('transactions')
          .where('userId', isEqualTo: employerId)
          .where('status', isEqualTo: 'completed')
          .where('createdAt', isGreaterThanOrEqualTo: startTs)
          .where('createdAt', isLessThan: endTs)
          .get();

      double totalSpent = 0.0;
      double totalDeposited = 0.0;

      for (final doc in txnSnap.docs) {
        final data = doc.data();
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

  /// Lấy dữ liệu biểu đồ, nhóm theo [period]
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
          .where('createdAt', isGreaterThanOrEqualTo: startTs)
          .where('createdAt', isLessThan: endTs)
          .get();

      // Fetch transactions
      final txnSnap = await _db
          .collection('transactions')
          .where('userId', isEqualTo: employerId)
          .where('status', isEqualTo: 'completed')
          .where('createdAt', isGreaterThanOrEqualTo: startTs)
          .where('createdAt', isLessThan: endTs)
          .get();

      // Build bucket map
      final buckets = _buildBuckets(start, end, period);

      for (final doc in jobsSnap.docs) {
        final data = doc.data();
        final ts = (data['createdAt'] as Timestamp?)?.toDate();
        if (ts == null) continue;
        final key = _bucketKey(ts, period);
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
        if (ts == null) continue;
        final key = _bucketKey(ts, period);
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
              label: e.key,
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
    StatsPeriod period,
  ) {
    final map = <String, _Bucket>{};
    DateTime cursor = _normalize(start, period);
    final limit = end.add(const Duration(days: 1));
    while (cursor.isBefore(limit)) {
      final key = _bucketKey(cursor, period);
      map[key] = _Bucket();
      cursor = _advance(cursor, period);
    }
    return map;
  }

  DateTime _normalize(DateTime dt, StatsPeriod period) {
    switch (period) {
      case StatsPeriod.day:
        return DateTime(dt.year, dt.month, dt.day, dt.hour);
      case StatsPeriod.week:
      case StatsPeriod.month:
        return DateTime(dt.year, dt.month, dt.day);
      case StatsPeriod.year:
        return DateTime(dt.year, dt.month);
    }
  }

  DateTime _advance(DateTime dt, StatsPeriod period) {
    switch (period) {
      case StatsPeriod.day:
        return dt.add(const Duration(hours: 1));
      case StatsPeriod.week:
        return dt.add(const Duration(days: 1));
      case StatsPeriod.month:
        return dt.add(const Duration(days: 7));
      case StatsPeriod.year:
        return DateTime(dt.year, dt.month + 1);
    }
  }

  String _bucketKey(DateTime dt, StatsPeriod period) {
    switch (period) {
      case StatsPeriod.day:
        return DateFormat('HH:mm').format(dt);
      case StatsPeriod.week:
        return DateFormat('EEE', 'vi').format(dt);
      case StatsPeriod.month:
        return DateFormat('dd/MM').format(dt);
      case StatsPeriod.year:
        return DateFormat('MMM', 'vi').format(dt);
    }
  }
}

class _Bucket {
  double spent = 0.0;
  double deposited = 0.0;
  int hired = 0;
  int posts = 0;
}
