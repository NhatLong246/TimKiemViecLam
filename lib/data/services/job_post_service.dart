import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/job_post_model.dart';
import 'job_workflow_service.dart';
import 'sqlite_cache_service.dart';

class JobPostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _collection = 'jobPosts';
  static const Duration _queryTimeout = Duration(seconds: 10);

  // ── Tạo bài đăng mới ───────────────────────────────────────────────────────
  Future<String> createJobPost(JobPostModel post) async {
    // Duplicate check: cùng title + employerId + startDate
    final existing = await _db
        .collection(_collection)
        .where('employerId', isEqualTo: post.employerId)
        .where('title', isEqualTo: post.title)
        .where('startDate', isEqualTo: Timestamp.fromDate(post.startDate))
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Bài đăng với tiêu đề và ngày bắt đầu này đã tồn tại.');
    }

    final docRef = _db.collection(_collection).doc();
    final newPost = post.copyWith(
      jobId: docRef.id,
      filledSlots: 0,
      totalBudget: post.salary * post.slots,
    );

    await docRef.set(newPost.toMap());
    return docRef.id;
  }

  // ── Lấy tất cả bài đăng của employer ──────────────────────────────────────
  // Không dùng orderBy trên Firestore → tránh yêu cầu composite index
  // Sắp xếp theo createdAt giảm dần bên phía Dart
  Stream<List<JobPostModel>> getJobPostsByEmployer(String employerId) {
    return _db
        .collection(_collection)
        .where('employerId', isEqualTo: employerId)
        .snapshots()
        .map((snap) {
          final posts = snap.docs
              .map((doc) => JobPostModel.fromMap(doc.data()))
              .toList();
          posts.sort((a, b) {
            final aTime = a.createdAt ?? DateTime(2000);
            final bTime = b.createdAt ?? DateTime(2000);
            return bTime.compareTo(aTime); // mới nhất trước
          });
          return posts;
        });
  }

  // ── Lấy danh sách việc làm mới nhất (cho ứng viên) ───────────────────────
  Future<List<JobPostModel>> getLatestActiveJobs() async {
    try {
      final jobs = await _fetchLatestFromFirestore();
      if (jobs.isNotEmpty) {
        await _cacheJobs(jobs);
      }
      return jobs;
    } on TimeoutException {
      final cached = await _fetchLatestFromSqlite();
      if (cached.isNotEmpty) return cached;
      throw Exception(
        'Không kết nối được máy chủ (quá 10 giây). '
        'Kiểm tra mạng trên emulator rồi kéo xuống để tải lại.',
      );
    } catch (_) {
      final cached = await _fetchLatestFromSqlite();
      if (cached.isNotEmpty) return cached;
      throw Exception(
        'Không tải được danh sách việc làm. Kiểm tra kết nối mạng và thử lại.',
      );
    }
  }

  Future<List<JobPostModel>> _fetchLatestFromFirestore() async {
    const opts = GetOptions(source: Source.serverAndCache);
    final futures = await Future.wait([
      _db
          .collection(_collection)
          .where('status', isEqualTo: 'approved')
          .get(opts),
      _db
          .collection(_collection)
          .where('status', isEqualTo: 'active')
          .get(opts),
    ]).timeout(_queryTimeout);

    final allDocs = [...futures[0].docs, ...futures[1].docs];
    if (allDocs.isEmpty) return [];

    final jobs = allDocs
        .map((doc) => JobPostModel.fromMap({...doc.data(), 'jobId': doc.id}))
        .toList();

    jobs.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(2000);
      final bTime = b.createdAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    return jobs;
  }

  Future<void> _cacheJobs(List<JobPostModel> jobs) async {
    for (final job in jobs) {
      await SqliteCacheService.upsertJob({
        'jobId': job.jobId,
        'employerId': job.employerId,
        'title': job.title,
        'category': job.category,
        'jobType': job.jobType,
        'location': jsonEncode(job.location),
        'salary': job.salary,
        'salaryType': job.salaryType,
        'slots': job.slots,
        'startDate': job.startDate.millisecondsSinceEpoch,
        'status': job.status,
      });
    }
  }

  Future<List<JobPostModel>> _fetchLatestFromSqlite() async {
    final rows = await SqliteCacheService.getCachedJobs();
    final jobs = rows
        .where((r) {
          final s = r['status'] as String? ?? '';
          return s == 'approved' || s == 'active';
        })
        .map(_jobFromCacheRow)
        .toList();
    jobs.sort((a, b) {
      final aTime = a.createdAt ?? a.startDate;
      final bTime = b.createdAt ?? b.startDate;
      return bTime.compareTo(aTime);
    });
    return jobs;
  }

  JobPostModel _jobFromCacheRow(Map<String, dynamic> row) {
    Map<String, dynamic> location = {};
    final rawLocation = row['location'];
    if (rawLocation is String && rawLocation.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawLocation);
        if (decoded is Map<String, dynamic>) location = decoded;
      } catch (_) {}
    }

    final startMs = row['startDate'] as int?;
    return JobPostModel(
      jobId: row['jobId'] as String? ?? '',
      employerId: row['employerId'] as String? ?? '',
      title: row['title'] as String? ?? '',
      description: '',
      category: row['category'] as String? ?? '',
      jobType: row['jobType'] as String? ?? 'part_time',
      location: location,
      salary: (row['salary'] as num?)?.toDouble() ?? 0,
      salaryType: row['salaryType'] as String? ?? 'per_day',
      slots: (row['slots'] as num?)?.toInt() ?? 1,
      startDate: startMs != null
          ? DateTime.fromMillisecondsSinceEpoch(startMs)
          : DateTime.now(),
      status: row['status'] as String? ?? 'active',
      totalBudget: 0,
    );
  }

  // ── Cập nhật trạng thái bài đăng ─────────────────────────────────────────
  Future<void> updateStatus(String jobId, String status) async {
    await _db.collection(_collection).doc(jobId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Cập nhật bài đăng ────────────────────────────────────────────────────
  Future<void> updateJobPost(JobPostModel post) async {
    final data = post.toMap();
    data.remove('createdAt'); // Không ghi đè createdAt
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection(_collection).doc(post.jobId).update(data);
  }

  // ── Xóa bài đăng ─────────────────────────────────────────────────────────
  Future<void> deleteJobPost(String jobId) async {
    final blocked = await JobWorkflowService().hasBlockingDisbursementNotice(
      jobId,
    );
    if (blocked) {
      throw Exception(
        'Không thể xóa: còn thông báo giải ngân chưa được Admin và NTD xác nhận.',
      );
    }
    await _db.collection(_collection).doc(jobId).update({
      'status': 'deleted',
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Lấy 1 bài đăng ───────────────────────────────────────────────────────
  Future<JobPostModel?> getJobPostById(String jobId) async {
    final doc = await _db.collection(_collection).doc(jobId).get();
    if (!doc.exists) return null;
    return JobPostModel.fromMap(doc.data()!);
  }
}
