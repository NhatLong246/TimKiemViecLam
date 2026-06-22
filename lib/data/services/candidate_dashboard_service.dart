import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/application_model.dart';
import '../models/candidate_dashboard_models.dart';
import '../models/candidate_dashboard_models.dart';
import '../models/disbursement_notice_model.dart';
import '../models/employer_stats_model.dart';
import '../models/job_post_model.dart';
import 'attendance_service.dart';
import 'notification_service.dart';
import 'candidate_earnings_service.dart';

enum BucketInterval { hour, day, week, month }

class CandidateDashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AttendanceService _attendance = AttendanceService();

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _groupsCol {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('workGroups');
  }

  Future<List<_AcceptedJobRow>> _fetchAcceptedRows() async {
    final uid = _uid;
    if (uid == null) return [];

    final appsSnap = await _firestore
        .collection('applications')
        .where('candidateId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();

    if (appsSnap.docs.isEmpty) return [];

    final apps = appsSnap.docs
        .map((d) => ApplicationModel.fromMap({...d.data(), 'appId': d.id}))
        .toList();

    final jobIds = apps
        .map((a) => a.jobId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final employerIds = apps
        .map((a) => a.employerId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final jobs = await _fetchJobs(jobIds);
    final employers = await _fetchEmployerNames(employerIds);

    final rows = <_AcceptedJobRow>[];
    for (final app in apps) {
      final job = jobs[app.jobId];
      if (job == null) continue;
      rows.add(
        _AcceptedJobRow(
          application: app,
          job: job,
          employerName: employers[app.employerId] ?? 'Nhà tuyển dụng',
        ),
      );
    }

    rows.sort((a, b) {
      final da =
          a.application.updatedAt ??
          a.application.appliedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db =
          b.application.updatedAt ??
          b.application.appliedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return rows;
  }

  Future<Map<String, JobPostModel>> _fetchJobs(List<String> jobIds) async {
    final result = <String, JobPostModel>{};
    if (jobIds.isEmpty) return result;

    for (var i = 0; i < jobIds.length; i += 30) {
      final chunk = jobIds.sublist(
        i,
        i + 30 > jobIds.length ? jobIds.length : i + 30,
      );
      final snap = await _firestore
          .collection('jobPosts')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        result[doc.id] = JobPostModel.fromMap({...doc.data(), 'jobId': doc.id});
      }
    }
    return result;
  }

  Future<Map<String, String>> _fetchEmployerNames(List<String> uids) async {
    final result = <String, String>{};
    if (uids.isEmpty) return result;

    for (var i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(
        i,
        i + 30 > uids.length ? uids.length : i + 30,
      );
      final snap = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        final first = (d['firstName'] as String?) ?? '';
        final last = (d['lastName'] as String?) ?? '';
        final name = '$first $last'.trim();
        result[doc.id] = name.isEmpty ? 'Nhà tuyển dụng' : name;
      }
    }
    return result;
  }

  CandidatePayment _rowToPayment(
    _AcceptedJobRow row, {
    DisbursementNoticeModel? notice,
    DateTime? completedAt,
    bool isDisputed = false,
  }) {
    final completed = notice?.status == 'completed';

    String status;
    if (isDisputed) {
      status = 'disputed';
    } else if (completed) {
      status = 'paid';
    } else {
      status = 'pending';
    }

    final amountVnd = completed && notice != null
        ? notice.amount.round()
        : row.job.salary.round();

    return CandidatePayment(
      id: row.application.appId,
      jobTitle: row.job.title,
      employerName: row.employerName,
      amountVnd: amountVnd,
      status: status,
      paidAt: completed ? completedAt : null,
      benefitNote: row.job.salaryDisplay,
    );
  }

  Future<Map<String, DisbursementNoticeModel>> _fetchLatestNoticeByJob(
    List<String> jobIds,
  ) async {
    final result = <String, DisbursementNoticeModel>{};
    if (jobIds.isEmpty) return result;

    for (var i = 0; i < jobIds.length; i += 30) {
      final chunk = jobIds.sublist(
        i,
        i + 30 > jobIds.length ? jobIds.length : i + 30,
      );
      final snap = await _firestore
          .collection('disbursementNotices')
          .where('jobId', whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final notice = DisbursementNoticeModel.fromMap(doc.data(), doc.id);
        final existing = result[notice.jobId];
        if (existing == null || notice.createdAt.isAfter(existing.createdAt)) {
          result[notice.jobId] = notice;
        }
      }
    }
    return result;
  }

  Future<Map<String, DateTime?>> _fetchCompletedAtByJob(
    List<String> jobIds,
  ) async {
    final result = <String, DateTime?>{};
    if (jobIds.isEmpty) return result;

    for (var i = 0; i < jobIds.length; i += 30) {
      final chunk = jobIds.sublist(
        i,
        i + 30 > jobIds.length ? jobIds.length : i + 30,
      );
      final snap = await _firestore
          .collection('disbursementNotices')
          .where('jobId', whereIn: chunk)
          .where('status', isEqualTo: 'completed')
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final jobId = data['jobId'] as String? ?? '';
        if (jobId.isEmpty) continue;
        final completedAt = _parseTimestamp(data['completedAt']);
        final existing = result[jobId];
        if (existing == null ||
            (completedAt != null && completedAt.isAfter(existing))) {
          result[jobId] = completedAt;
        }
      }
    }
    return result;
  }

  Future<Set<String>> _fetchDisputedJobIds(String uid) async {
    final disputed = <String>{};

    final incidents = await _firestore
        .collection('incidents')
        .where('workerId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .limit(50)
        .get();
    for (final doc in incidents.docs) {
      final jobId = doc.data()['jobId'] as String? ?? '';
      if (jobId.isNotEmpty) disputed.add(jobId);
    }

    final jobComplaints = await _firestore
        .collection('jobComplaints')
        .where('candidateId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .limit(50)
        .get();
    for (final doc in jobComplaints.docs) {
      final jobId = doc.data()['jobId'] as String? ?? '';
      if (jobId.isNotEmpty) disputed.add(jobId);
    }

    return disputed;
  }

  Future<double> _computeHoursWorked(
    String uid,
    List<_AcceptedJobRow> rows, {
    DateTime? start,
    DateTime? end,
  }) async {
    var total = 0.0;
    for (final row in rows) {
      final hoursPerDay = row.job.workHoursPerDay ?? 4.0;
      final sessions = await _attendance.fetchAllByJob(row.job.jobId);
      for (final session in sessions) {
        final sessionDate = DateTime.tryParse(session.date);
        if (sessionDate != null) {
          if (start != null && sessionDate.isBefore(start)) continue;
          if (end != null && sessionDate.isAfter(end)) continue;
        }

        for (final rec in session.records) {
          if (rec.candidateId != uid) continue;
          if (rec.status == 'absent' || rec.status == 'not_marked') continue;
          total += hoursPerDay;
        }
      }
    }
    return total;
  }

  static DateTime? _parseTimestamp(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static bool _isInRange(DateTime? date, DateTime? start, DateTime? end) {
    if (date == null) return false;
    if (start != null && date.isBefore(start)) return false;
    if (end != null && date.isAfter(end)) return false;
    return true;
  }

  Future<List<CandidatePayment>> fetchPayments() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _fetchAcceptedRows();
    if (rows.isEmpty) return [];

    final jobIds = rows.map((r) => r.job.jobId).toList();
    final notices = await _fetchLatestNoticeByJob(jobIds);
    final completedAtByJob = await _fetchCompletedAtByJob(jobIds);
    final disputedJobs = await _fetchDisputedJobIds(uid);

    return rows
        .map(
          (row) => _rowToPayment(
            row,
            notice: notices[row.job.jobId],
            completedAt: completedAtByJob[row.job.jobId],
            isDisputed: disputedJobs.contains(row.job.jobId),
          ),
        )
        .toList();
  }

  Future<List<ReviewableJob>> fetchReviewableJobs() async {
    final rows = await _fetchAcceptedRows();
    final now = DateTime.now();

    return rows
        .where((r) {
          final job = r.job;
          if (job.status == 'closed') return true;

          final end = job.endDate ?? job.startDate;
          // Xem như kết thúc nếu đã sang ngày hôm sau của endDate
          final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
          if (now.isAfter(endOfDay)) return true;

          return false;
        })
        .map(
          (r) => ReviewableJob(
            jobId: r.job.jobId,
            employerId: r.application.employerId,
            jobTitle: r.job.title,
            employerName: r.employerName,
          ),
        )
        .toList();
  }

  Future<List<CandidateReviewGiven>> fetchReviewsGiven() async {
    final uid = _uid;
    if (uid == null) return [];

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _firestore
          .collection('reviews')
          .where('reviewerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();
    } catch (_) {
      snap = await _firestore
          .collection('reviews')
          .where('reviewerId', isEqualTo: uid)
          .get();
    }

    if (snap.docs.isEmpty) return [];

    final jobIds = <String>{};
    final employerIds = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final jobId = (data['jobId'] as String?) ?? '';
      final revieweeId = (data['revieweeId'] as String?) ?? '';
      if (jobId.isNotEmpty) jobIds.add(jobId);
      if (revieweeId.isNotEmpty) employerIds.add(revieweeId);
    }

    final jobs = await _fetchJobs(jobIds.toList());
    final employers = await _fetchEmployerNames(employerIds.toList());

    final list = snap.docs.map((doc) {
      final data = doc.data();
      final jobId = (data['jobId'] as String?) ?? '';
      final revieweeId = (data['revieweeId'] as String?) ?? '';
      final job = jobs[jobId];
      final rawTags = data['tags'];

      return CandidateReviewGiven(
        id: doc.id,
        employerName: employers[revieweeId] ?? 'Nhà tuyển dụng',
        jobTitle: job?.title ?? 'Công việc',
        rating: (data['rating'] as num?)?.toDouble() ?? 0,
        comment: data['comment']?.toString(),
        tags: rawTags is List
            ? rawTags.map((e) => e.toString()).toList()
            : const [],
        createdAt: CandidateReviewGiven.parseDate(data['createdAt']),
      );
    }).toList();

    list.sort((a, b) {
      final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return list;
  }

  Future<List<CandidateReviewGiven>> fetchReviewsReceived() async {
    final uid = _uid;
    if (uid == null) return [];

    final snap = await _firestore
        .collection('reviews')
        .where('revieweeId', isEqualTo: uid)
        .get();

    if (snap.docs.isEmpty) return [];

    final jobIds = <String>{};
    final employerIds = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final jobId = (data['jobId'] as String?) ?? '';
      final reviewerId = (data['reviewerId'] as String?) ?? '';
      if (jobId.isNotEmpty) jobIds.add(jobId);
      if (reviewerId.isNotEmpty) employerIds.add(reviewerId);
    }

    final jobs = await _fetchJobs(jobIds.toList());
    final employers = await _fetchEmployerNames(employerIds.toList());

    final list = snap.docs.map((doc) {
      final data = doc.data();
      final jobId = (data['jobId'] as String?) ?? '';
      final reviewerId = (data['reviewerId'] as String?) ?? '';
      final job = jobs[jobId];
      final rawTags = data['tags'];

      return CandidateReviewGiven(
        id: doc.id,
        employerName: employers[reviewerId] ?? 'Nhà tuyển dụng',
        jobTitle: job?.title ?? 'Công việc',
        rating: (data['rating'] as num?)?.toDouble() ?? 0,
        comment: data['comment']?.toString(),
        tags: rawTags is List
            ? rawTags.map((e) => e.toString()).toList()
            : const [],
        createdAt: CandidateReviewGiven.parseDate(data['createdAt']),
      );
    }).toList();

    list.sort((a, b) {
      final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    // Tự động đồng bộ lại điểm uy tín nếu bị lệch (Self-healing)
    double total = 0;
    int count = 0;
    for (final doc in snap.docs) {
      final r = (doc.data()['rating'] as num?)?.toDouble() ?? 0;
      if (r > 0) {
        total += r;
        count++;
      }
    }
    final avg = count > 0 ? total / count : 0.0;
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final currentAvg =
          (userDoc.data()?['averageRating'] as num?)?.toDouble() ?? 0.0;
      if ((avg - currentAvg).abs() > 0.01) {
        await _firestore.collection('users').doc(uid).update({
          'averageRating': avg,
          'reviewCount': count,
        });
      }
    } catch (_) {}

    return list;
  }

  Future<List<WorkGroup>> fetchWorkGroups() async {
    final col = _groupsCol;
    if (col == null) return [];

    final snap = await col.get();
    final list = snap.docs
        .map((d) => WorkGroup.fromMap(d.id, d.data()))
        .toList();
    list.sort((a, b) {
      final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return list;
  }

  Future<CandidateEarningsSummary> fetchSummary({
    required List<CandidatePayment> payments,
    required double profileRating,
    DateTime? start,
    DateTime? end,
  }) async {
    var paid = 0;
    var periodPaid = 0;
    var pending = 0;

    for (final p in payments) {
      if (p.status == 'paid') {
        paid += p.amountVnd;
        if (_isInRange(p.paidAt, start, end)) {
          periodPaid += p.amountVnd;
        }
      } else if (p.status == 'pending') {
        pending += p.amountVnd;
      }
    }

    final rows = await _fetchAcceptedRows();
    final uid = _uid ?? '';
    final hours = uid.isEmpty ? 0.0 : await _computeHoursWorked(uid, rows, start: start, end: end);
    final walletBalance = await _fetchWalletBalance();

    return CandidateEarningsSummary(
      totalPaidVnd: paid,
      periodPaidVnd: periodPaid,
      pendingVnd: pending,
      walletBalanceVnd: walletBalance.round(),
      jobCount: payments.where((p) => p.status == 'paid').length,
      hoursWorked: hours.round(),
      avgRating: profileRating,
    );
  }

  BucketInterval _getInterval(DateTime start, DateTime end) {
    final diffDays = end.difference(start).inDays;
    if (diffDays <= 2) return BucketInterval.hour;
    if (diffDays <= 31) return BucketInterval.day;
    if (diffDays <= 120) return BucketInterval.week;
    return BucketInterval.month;
  }

  Future<List<CandidateChartPoint>> fetchChartData({
    required List<CandidatePayment> payments,
    required DateTime start,
    required DateTime end,
    required StatsPeriod period,
  }) async {
    final uid = _uid;
    if (uid == null) return [];

    final interval = _getInterval(start, end);
    final buckets = _buildBuckets(start, end, interval);
    
    for (final p in payments) {
      final date = p.paidAt ?? DateTime.now();
      if (date.isBefore(start) || date.isAfter(end)) continue;

      final key = _bucketKey(date, interval);
      if (buckets.containsKey(key)) {
        if (p.status == 'paid') {
          buckets[key] = CandidateChartPoint(
            label: buckets[key]!.label,
            paidVnd: buckets[key]!.paidVnd + p.amountVnd,
            pendingVnd: buckets[key]!.pendingVnd,
            completedJobs: buckets[key]!.completedJobs + 1,
            hoursWorked: buckets[key]!.hoursWorked,
          );
        } else if (p.status == 'pending') {
          buckets[key] = CandidateChartPoint(
            label: buckets[key]!.label,
            paidVnd: buckets[key]!.paidVnd,
            pendingVnd: buckets[key]!.pendingVnd + p.amountVnd,
            completedJobs: buckets[key]!.completedJobs,
            hoursWorked: buckets[key]!.hoursWorked,
          );
        }
      }
    }

    final rows = await _fetchAcceptedRows();
    for (final row in rows) {
      final hoursPerDay = row.job.workHoursPerDay ?? 4.0;
      final sessions = await _attendance.fetchAllByJob(row.job.jobId);
      for (final session in sessions) {
        final sessionDate = DateTime.tryParse(session.date);
        if (sessionDate == null) continue;
        if (sessionDate.isBefore(start) || sessionDate.isAfter(end)) continue;
        final key = _bucketKey(sessionDate, interval);
        if (buckets.containsKey(key)) {
          for (final rec in session.records) {
            if (rec.candidateId != uid) continue;
            if (rec.status == 'absent' || rec.status == 'not_marked') continue;
            
            buckets[key] = CandidateChartPoint(
              label: buckets[key]!.label,
              paidVnd: buckets[key]!.paidVnd,
              pendingVnd: buckets[key]!.pendingVnd,
              completedJobs: buckets[key]!.completedJobs,
              hoursWorked: buckets[key]!.hoursWorked + hoursPerDay,
            );
          }
        }
      }
    }

    final list = buckets.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return list.map((e) => e.value).toList();
  }

  Map<String, CandidateChartPoint> _buildBuckets(
      DateTime start, DateTime end, BucketInterval interval) {
    final map = <String, CandidateChartPoint>{};
    var current = _normalize(start, interval);
    final limit = end.add(const Duration(days: 1));
    
    while (current.isBefore(limit)) {
      final key = _bucketKey(current, interval);
      if (!map.containsKey(key)) {
        map[key] = CandidateChartPoint(
          label: _bucketLabel(current, interval),
          paidVnd: 0,
          pendingVnd: 0,
          completedJobs: 0,
          hoursWorked: 0,
        );
      }
      current = _advance(current, interval);
    }
    return map;
  }

  DateTime _normalize(DateTime dt, BucketInterval interval) {
    switch (interval) {
      case BucketInterval.hour:
        return DateTime(dt.year, dt.month, dt.day, dt.hour);
      case BucketInterval.day:
      case BucketInterval.week:
        return DateTime(dt.year, dt.month, dt.day);
      case BucketInterval.month:
        return DateTime(dt.year, dt.month);
    }
  }

  DateTime _advance(DateTime dt, BucketInterval interval) {
    switch (interval) {
      case BucketInterval.hour:
        return dt.add(const Duration(hours: 1));
      case BucketInterval.day:
        return dt.add(const Duration(days: 1));
      case BucketInterval.week:
        return dt.add(const Duration(days: 7));
      case BucketInterval.month:
        return DateTime(dt.year, dt.month + 1);
    }
  }

  String _bucketKey(DateTime date, BucketInterval interval) {
    switch (interval) {
      case BucketInterval.hour:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:00';
      case BucketInterval.day:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      case BucketInterval.week:
        final w = ((date.day - 1) / 7).floor() + 1;
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-W$w';
      case BucketInterval.month:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }
  }

  String _bucketLabel(DateTime date, BucketInterval interval) {
    switch (interval) {
      case BucketInterval.hour:
        return '${date.hour.toString().padLeft(2, '0')}:00';
      case BucketInterval.day:
        return '${date.day}/${date.month}';
      case BucketInterval.week:
        final w = ((date.day - 1) / 7).floor() + 1;
        return 'Tuần $w T${date.month}';
      case BucketInterval.month:
        return 'T${date.month}';
    }
  }

  Future<double> _fetchWalletBalance() async {
    final uid = _uid;
    if (uid == null) return 0;
    return CandidateEarningsService().getTotalEarnings(uid);
  }

  Future<void> withdraw({required int amountVnd, String? note}) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');
    if (amountVnd <= 0) throw Exception('Số tiền rút phải lớn hơn 0');

    final userRef = _firestore.collection('users').doc(uid);
    final txRef = _firestore.collection('walletTransactions').doc();

    await _firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final balance =
          (userSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
      if (balance < amountVnd) {
        throw Exception('Số dư không đủ để rút');
      }

      tx.set(txRef, {
        'userId': uid,
        'type': 'withdraw',
        'amount': amountVnd,
        'status': 'completed',
        'description': (note != null && note.trim().isNotEmpty)
            ? note.trim()
            : 'Rút tiền về tài khoản',
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(userRef, {
        'walletBalance': FieldValue.increment(-amountVnd),
        'totalWithdrawn': FieldValue.increment(amountVnd),
      }, SetOptions(merge: true));
    });
  }

  Future<void> submitReview({
    required String jobId,
    required String employerId,
    required double rating,
    String? comment,
    List<String> tags = const [],
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');
    if (jobId.isEmpty || employerId.isEmpty) {
      throw Exception('Chọn công việc đã được nhận để đánh giá');
    }

    await _firestore.collection('reviews').add({
      'jobId': jobId,
      'reviewerId': uid,
      'revieweeId': employerId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      if (tags.isNotEmpty) 'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Cập nhật điểm uy tín cho NTD
    try {
      final snap = await _firestore
          .collection('reviews')
          .where('revieweeId', isEqualTo: employerId)
          .get();
      double total = 0;
      int count = 0;
      for (final doc in snap.docs) {
        final r = (doc.data()['rating'] as num?)?.toDouble() ?? 0;
        if (r > 0) {
          total += r;
          count++;
        }
      }
      final avg = count > 0 ? total / count : 0.0;
      await _firestore.collection('users').doc(employerId).update({
        'averageRating': avg,
        'reviewCount': count,
      });
    } catch (_) {}

    var jobTitle = 'Công việc';
    var candidateName = 'Ứng viên';
    try {
      final jobDoc = await _firestore.collection('jobPosts').doc(jobId).get();
      if (jobDoc.exists) {
        jobTitle = (jobDoc.data()?['title'] ?? jobTitle).toString();
      }
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final d = userDoc.data() ?? {};
        final combined = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'
            .trim();
        if (combined.isNotEmpty) candidateName = combined;
      }
    } catch (_) {}

    await NotificationService.notifyEmployerReview(
      employerId: employerId,
      candidateName: candidateName,
      jobTitle: jobTitle,
      rating: rating,
      jobId: jobId,
    );
  }

  Future<WorkGroup> createGroup(String name) async {
    final uid = _uid;
    final col = _groupsCol;
    if (uid == null || col == null) throw Exception('Chưa đăng nhập');

    final code = _randomInviteCode();
    final data = {
      'name': name.trim(),
      'inviteCode': code,
      'leaderId': uid,
      'memberIds': [uid],
      'completedShifts': 0,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final publicRef = _firestore.collection('publicWorkGroups').doc();
    await publicRef.set(data);

    await col.doc(publicRef.id).set({...data, 'publicGroupId': publicRef.id});
    final doc = await col.doc(publicRef.id).get();
    return WorkGroup.fromMap(publicRef.id, doc.data()!);
  }

  Future<WorkGroup> joinGroup(String inviteCode) async {
    final uid = _uid;
    final col = _groupsCol;
    if (uid == null || col == null) throw Exception('Chưa đăng nhập');

    final normalized = inviteCode.trim().toUpperCase();
    final query = await _firestore
        .collection('publicWorkGroups')
        .where('inviteCode', isEqualTo: normalized)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Mã nhóm không tồn tại');
    }

    final doc = query.docs.first;
    final data = Map<String, dynamic>.from(doc.data());
    final members = List<String>.from(
      (data['memberIds'] as List?)?.map((e) => e.toString()) ?? [],
    );
    if (!members.contains(uid)) {
      members.add(uid);
      await doc.reference.update({'memberIds': members});
      data['memberIds'] = members;
    }

    await col.doc(doc.id).set(data, SetOptions(merge: true));
    return WorkGroup.fromMap(doc.id, data);
  }

  String _randomInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

class _AcceptedJobRow {
  final ApplicationModel application;
  final JobPostModel job;
  final String employerName;

  const _AcceptedJobRow({
    required this.application,
    required this.job,
    required this.employerName,
  });
}
