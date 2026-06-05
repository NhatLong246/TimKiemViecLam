import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/job_post_model.dart';
import '../../utils/job_time_helper.dart';
import 'job_pricing_service.dart';
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
    final quote = JobPricingService.quote(post);
    final newPost = post.copyWith(
      jobId: docRef.id,
      filledSlots: 0,
      totalBudget: quote.totalBudget,
      depositStatus: 'none',
      depositCalculation: quote.toMap(),
    );

    if (_mustHoldDeposit(newPost, quote)) {
      await _createPostWithDepositHold(docRef, newPost, quote);
    } else {
      final data = newPost.toMap();
      _clearDepositState(data);
      await docRef.set(data);
    }
    return docRef.id;
  }

  // ── Ví ứng tiền bài đăng ─────────────────────────────────────────────────
  bool _mustHoldDeposit(JobPostModel post, JobDepositQuote quote) {
    return quote.requiresDeposit && post.status != 'draft';
  }

  Future<void> _createPostWithDepositHold(
    DocumentReference<Map<String, dynamic>> jobRef,
    JobPostModel post,
    JobDepositQuote quote,
  ) async {
    final txId = 'job_deposit_hold_${jobRef.id}';
    await _db.runTransaction((transaction) async {
      await _holdDeposit(
        transaction,
        employerId: post.employerId,
        amount: quote.depositAmount,
        jobId: jobRef.id,
        transactionId: txId,
        description: 'Tạm giữ tiền ứng cho bài đăng "${post.title}"',
      );

      final data = post
          .copyWith(
            totalBudget: quote.totalBudget,
            depositStatus: 'held',
            depositTransactionId: txId,
            depositCalculation: quote.toMap(),
          )
          .toMap();
      data['depositHeldAt'] = FieldValue.serverTimestamp();
      transaction.set(jobRef, data);
    });
  }

  Future<String> _holdDeposit(
    Transaction transaction, {
    required String employerId,
    required double amount,
    required String jobId,
    required String transactionId,
    required String description,
  }) async {
    if (amount <= 0) return transactionId;
    if (employerId.isEmpty) throw Exception('Chưa đăng nhập.');

    final userRef = _db.collection('users').doc(employerId);
    final userSnap = await transaction.get(userRef);
    if (!userSnap.exists) {
      throw Exception('Không tìm thấy tài khoản doanh nghiệp.');
    }

    final data = userSnap.data() ?? {};
    final balance = (data['walletBalance'] as num?)?.toDouble() ?? 0;
    if (balance < amount) {
      final missing = amount - balance;
      throw Exception(
        'Số dư tiền app không đủ để ứng trước. '
        'Cần ${_vnd(amount)}, hiện có ${_vnd(balance)}, thiếu ${_vnd(missing)}.',
      );
    }

    final txRef = _db.collection('walletTransactions').doc(transactionId);
    transaction.set(txRef, {
      'userId': employerId,
      'type': 'job_deposit_hold',
      'amount': amount,
      'description': description,
      'status': 'completed',
      'paymentMethod': 'wallet',
      'jobId': jobId,
      'idempotencyKey': transactionId,
      'balanceBefore': balance,
      'balanceAfter': balance - amount,
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
    });
    transaction.set(userRef, {
      'walletBalance': FieldValue.increment(-amount),
      'walletHeldBalance': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return transactionId;
  }

  void _refundHeldDeposit(
    Transaction transaction, {
    required JobPostModel post,
    required String transactionId,
    required String description,
    required Map<String, dynamic> jobUpdates,
  }) {
    final amount = post.totalBudget;
    if (amount <= 0) return;

    final userRef = _db.collection('users').doc(post.employerId);
    final txRef = _db.collection('walletTransactions').doc(transactionId);
    transaction.set(userRef, {
      'walletBalance': FieldValue.increment(amount),
      'walletHeldBalance': FieldValue.increment(-amount),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    transaction.set(txRef, {
      'userId': post.employerId,
      'type': 'refund',
      'amount': amount,
      'description': description,
      'status': 'completed',
      'paymentMethod': 'wallet',
      'jobId': post.jobId,
      'idempotencyKey': transactionId,
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
    });
    jobUpdates.addAll({
      'depositStatus': 'refunded',
      'depositRefundAmount': amount,
      'depositCompensationAmount': 0,
      'depositRefundedAt': FieldValue.serverTimestamp(),
    });
  }

  void _refundDepositDifference(
    Transaction transaction, {
    required String employerId,
    required String jobId,
    required double amount,
    required String transactionId,
    required String description,
  }) {
    if (amount <= 0) return;

    final userRef = _db.collection('users').doc(employerId);
    final txRef = _db.collection('walletTransactions').doc(transactionId);
    transaction.set(userRef, {
      'walletBalance': FieldValue.increment(amount),
      'walletHeldBalance': FieldValue.increment(-amount),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    transaction.set(txRef, {
      'userId': employerId,
      'type': 'refund',
      'amount': amount,
      'description': description,
      'status': 'completed',
      'paymentMethod': 'wallet',
      'jobId': jobId,
      'idempotencyKey': transactionId,
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> _updateMap(JobPostModel post) {
    final data = post.toMap();
    data.remove('createdAt');
    data['updatedAt'] = FieldValue.serverTimestamp();
    return data;
  }

  void _clearDepositState(Map<String, dynamic> data) {
    data['depositStatus'] = 'none';
    data.remove('depositTransactionId');
    data.remove('depositHeldAt');
    data.remove('depositRefundedAt');
    data.remove('depositReleasedAt');
    data.remove('depositRefundAmount');
    data.remove('depositCompensationAmount');
    data.remove('lastDepositAdjustmentTransactionId');
    data.remove('depositAdjustedAt');
  }

  static String _vnd(double v) =>
      '${NumberFormat('#,###', 'vi_VN').format(v.ceil())}đ';

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
      return _filterExpiredJobs(jobs);
    } on TimeoutException {
      final cached = await _fetchLatestFromSqlite();
      if (cached.isNotEmpty) return _filterExpiredJobs(cached);
      throw Exception(
        'Không kết nối được máy chủ (quá 10 giây). '
        'Kiểm tra mạng trên emulator rồi kéo xuống để tải lại.',
      );
    } catch (_) {
      final cached = await _fetchLatestFromSqlite();
      if (cached.isNotEmpty) return _filterExpiredJobs(cached);
      throw Exception(
        'Không tải được danh sách việc làm. Kiểm tra kết nối mạng và thử lại.',
      );
    }
  }

  List<JobPostModel> _filterExpiredJobs(List<JobPostModel> jobs) {
    final now = DateTime.now();
    return jobs.where((job) {
      final deadline = job.applicationDeadline;
      if (deadline != null && !deadline.isAfter(now)) {
        return false;
      }
      return true;
    }).toList();
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
        'filledSlots': job.filledSlots,
        'startDate': job.startDate.millisecondsSinceEpoch,
        'applicationDeadline': job.applicationDeadline?.millisecondsSinceEpoch,
        'createdAt': job.createdAt?.millisecondsSinceEpoch,
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
      filledSlots: (row['filledSlots'] as num?)?.toInt() ?? 0,
      startDate: startMs != null
          ? DateTime.fromMillisecondsSinceEpoch(startMs)
          : DateTime.now(),
      status: row['status'] as String? ?? 'active',
      totalBudget: 0,
      applicationDeadline: (row['applicationDeadline'] as int?) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              row['applicationDeadline'] as int,
            )
          : null,
      createdAt: (row['createdAt'] as int?) != null
          ? DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int)
          : null,
    );
  }

  // ── Cập nhật trạng thái bài đăng ─────────────────────────────────────────
  Future<void> updateStatus(String jobId, String status) async {
    if (status == 'pending') {
      await submitForReview(jobId);
      return;
    }
    if (status == 'draft') {
      await _updateStatusAndMaybeReleaseDeposit(jobId, status);
      return;
    }

    await _db.collection(_collection).doc(jobId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitForReview(String jobId) async {
    final jobRef = _db.collection(_collection).doc(jobId);
    final opId = DateTime.now().microsecondsSinceEpoch.toString();

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(jobRef);
      if (!snap.exists) throw Exception('Không tìm thấy bài đăng.');

      final existing = JobPostModel.fromMap({
        ...snap.data()!,
        'jobId': snap.id,
      });
      final pendingPost = existing.copyWith(status: 'pending');
      final quote = JobPricingService.quote(pendingPost);
      final updates = <String, dynamic>{
        'status': 'pending',
        'totalBudget': quote.totalBudget,
        'depositCalculation': quote.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_mustHoldDeposit(pendingPost, quote) &&
          existing.depositStatus != 'held') {
        final txId = 'job_deposit_hold_${jobId}_$opId';
        await _holdDeposit(
          transaction,
          employerId: existing.employerId,
          amount: quote.depositAmount,
          jobId: jobId,
          transactionId: txId,
          description: 'Tạm giữ tiền ứng cho bài đăng "${existing.title}"',
        );
        updates.addAll({
          'depositStatus': 'held',
          'depositTransactionId': txId,
          'depositHeldAt': FieldValue.serverTimestamp(),
          'depositRefundAmount': null,
          'depositCompensationAmount': null,
        });
      }

      transaction.update(jobRef, updates);
    });
  }

  // ── Cập nhật bài đăng ────────────────────────────────────────────────────
  Future<void> updateJobPost(JobPostModel post) async {
    final quote = JobPricingService.quote(post);
    final updatedPost = post.copyWith(
      totalBudget: quote.totalBudget,
      depositCalculation: quote.toMap(),
    );
    final jobRef = _db.collection(_collection).doc(post.jobId);
    final opId = DateTime.now().microsecondsSinceEpoch.toString();

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(jobRef);
      if (!snap.exists) throw Exception('Không tìm thấy bài đăng.');

      final existing = JobPostModel.fromMap({
        ...snap.data()!,
        'jobId': snap.id,
      });
      final data = _updateMap(updatedPost);

      if (_mustHoldDeposit(updatedPost, quote)) {
        if (existing.depositStatus == 'held') {
          final delta = quote.depositAmount - existing.totalBudget;
          data['depositStatus'] = 'held';

          if (delta > 0.5) {
            final txId = 'job_deposit_adjust_${post.jobId}_$opId';
            await _holdDeposit(
              transaction,
              employerId: post.employerId,
              amount: delta,
              jobId: post.jobId,
              transactionId: txId,
              description:
                  'Tạm giữ bổ sung do cập nhật ngân sách "${post.title}"',
            );
            data['lastDepositAdjustmentTransactionId'] = txId;
            data['depositAdjustedAt'] = FieldValue.serverTimestamp();
          } else if (delta < -0.5) {
            final refundAmount = -delta;
            final txId = 'job_deposit_refund_diff_${post.jobId}_$opId';
            _refundDepositDifference(
              transaction,
              employerId: post.employerId,
              jobId: post.jobId,
              amount: refundAmount,
              transactionId: txId,
              description:
                  'Hoàn phần chênh lệch do giảm ngân sách "${post.title}"',
            );
            data['lastDepositAdjustmentTransactionId'] = txId;
            data['depositAdjustedAt'] = FieldValue.serverTimestamp();
          }
        } else {
          final txId = 'job_deposit_hold_${post.jobId}_$opId';
          await _holdDeposit(
            transaction,
            employerId: post.employerId,
            amount: quote.depositAmount,
            jobId: post.jobId,
            transactionId: txId,
            description: 'Tạm giữ tiền ứng cho bài đăng "${post.title}"',
          );
          data.addAll({
            'depositStatus': 'held',
            'depositTransactionId': txId,
            'depositHeldAt': FieldValue.serverTimestamp(),
            'depositRefundAmount': null,
            'depositCompensationAmount': null,
          });
        }
      } else if (existing.depositStatus == 'held' &&
          (updatedPost.status == 'draft' || !quote.requiresDeposit)) {
        if (JobTimeHelper.hasStarted(existing)) {
          throw Exception('Công việc đã bắt đầu, không thể hoàn tiền ứng.');
        }
        _refundHeldDeposit(
          transaction,
          post: existing,
          transactionId: 'job_deposit_release_${post.jobId}_$opId',
          description: 'Hoàn tiền ứng do bài đăng không còn gửi duyệt',
          jobUpdates: data,
        );
      }

      transaction.update(jobRef, data);
    });
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
    await _updateStatusAndMaybeReleaseDeposit(
      jobId,
      'deleted',
      markDeleted: true,
    );
  }

  Future<void> _updateStatusAndMaybeReleaseDeposit(
    String jobId,
    String status, {
    bool markDeleted = false,
  }) async {
    final jobRef = _db.collection(_collection).doc(jobId);
    final opId = DateTime.now().microsecondsSinceEpoch.toString();

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(jobRef);
      if (!snap.exists) throw Exception('Không tìm thấy bài đăng.');

      final existing = JobPostModel.fromMap({
        ...snap.data()!,
        'jobId': snap.id,
      });
      final updates = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (markDeleted) 'deletedAt': FieldValue.serverTimestamp(),
      };

      if (existing.depositStatus == 'held') {
        if (JobTimeHelper.hasStarted(existing)) {
          throw Exception('Công việc đã bắt đầu, không thể hoàn tiền ứng.');
        }
        _refundHeldDeposit(
          transaction,
          post: existing,
          transactionId: 'job_deposit_release_${jobId}_$opId',
          description: status == 'deleted'
              ? 'Hoàn tiền ứng do xóa bài đăng'
              : 'Hoàn tiền ứng do rút bài về nháp',
          jobUpdates: updates,
        );
      }

      transaction.update(jobRef, updates);
    });
  }

  // ── Lấy 1 bài đăng ───────────────────────────────────────────────────────
  Future<JobPostModel?> getJobPostById(String jobId) async {
    final doc = await _db.collection(_collection).doc(jobId).get();
    if (!doc.exists) return null;
    return JobPostModel.fromMap({...doc.data()!, 'jobId': doc.id});
  }
}
