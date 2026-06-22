import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/disbursement_notice_model.dart';
import '../models/app_notification_model.dart';
import 'notification_service.dart';
import 'candidate_earnings_service.dart';
import 'disbursement_calculator.dart';
import 'wallet_service.dart';

class JobWorkflowService {
  final _db = FirebaseFirestore.instance;
  final _notif = NotificationService();
  final _earningsSvc = CandidateEarningsService();
  final _wallet = WalletService();

  String _money(double v) => '${NumberFormat('#,###', 'vi_VN').format(v)}đ';

  CollectionReference<Map<String, dynamic>> get _notices =>
      _db.collection('disbursementNotices');

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groupChats');

  // ═══════════════════════════════════════════════════════
  // QUERY
  // ═══════════════════════════════════════════════════════

  Future<bool> hasBlockingDisbursementNotice(String jobId) async {
    final snap = await _notices
        .where('jobId', isEqualTo: jobId)
        .limit(10)
        .get();
    for (final doc in snap.docs) {
      final s = doc.data()['status'] as String? ?? '';
      if ([
        'pending_admin',
        'approved',
        'pending_ack',
        'complaints_pending',
        'complaints_reviewed',
      ].contains(s)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> hasCompletedDisbursement(String jobId) async {
    final snap = await _notices
        .where('jobId', isEqualTo: jobId)
        .where('status', isEqualTo: 'completed')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<DisbursementNoticeModel?> getActiveRequestForJob(String jobId) async {
    final snap = await _notices
        .where('jobId', isEqualTo: jobId)
        .where(
          'status',
          whereIn: ['approved', 'complaints_pending', 'complaints_reviewed'],
        )
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return DisbursementNoticeModel.fromMap(d.data(), d.id);
  }

  Stream<DisbursementNoticeModel?> streamActiveRequestForJob(String jobId) {
    return _notices
        .where('jobId', isEqualTo: jobId)
        .where(
          'status',
          whereIn: ['approved', 'complaints_pending', 'complaints_reviewed'],
        )
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          final d = snap.docs.first;
          return DisbursementNoticeModel.fromMap(d.data(), d.id);
        });
  }

  /// Stream tất cả khiếu nại của NTD hiện tại (cho màn hình danh sách khiếu nại)
  Stream<List<DisbursementNoticeModel>> streamMyComplaints(String employerId) {
    return _notices
        .where('employerId', isEqualTo: employerId)
        .where('status', whereIn: ['complaints_pending', 'complaints_reviewed'])
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => DisbursementNoticeModel.fromMap(d.data(), d.id))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  // ═══════════════════════════════════════════════════════
  // BƯỚC 1: NTD BẤM GIẢI NGÂN → Tạo yêu cầu (approved luôn)
  // ═══════════════════════════════════════════════════════

  /// NTD yêu cầu giải ngân theo lương thực tế của từng ứng viên.
  Future<String> requestDisbursement({
    required String jobId,
    required String groupId,
    required String employerId,
    required String workDate,
    required double amount,
    required double totalEarned,
    required Map<String, double> candidateAmounts,
    required String jobTitle,
  }) async {
    final existing = await getActiveRequestForJob(jobId);
    if (existing != null) {
      throw Exception('Đã có yêu cầu giải ngân đang xử lý.');
    }

    final excessRefund = (amount - totalEarned).clamp(0.0, double.infinity);

    final ref = _notices.doc();
    await ref.set({
      'jobId': jobId,
      'groupId': groupId,
      'employerId': employerId,
      'workDate': workDate,
      'amount': amount,
      'totalEarned': totalEarned,
      'excessRefund': excessRefund,
      'jobTitle': jobTitle,
      'status': 'approved',
      'employerAck': false,
      'adminAck': true,
      'createdAt': FieldValue.serverTimestamp(),
      'approvedAt': FieldValue.serverTimestamp(),
      'candidateAmounts': candidateAmounts,
      'totalCandidates': candidateAmounts.length,
      'complainedCandidates': [],
      'deductions': {},
      'complaintReasons': {},
      'complaintEvidence': {},
      'complaintResults': {},
      'adminFinalDeductions': {},
      'adminNote': '',
      'ratedCandidates': [],
      'userDebts': {},
    });

    return ref.id;
  }

  // ═══════════════════════════════════════════════════════
  // BƯỚC 2A: GIẢI NGÂN KHÔNG KHIẾU NẠI
  // NTD chọn "Không khiếu nại" → chia tiền đều → xong
  // ═══════════════════════════════════════════════════════

  /// Giải ngân trực tiếp (không khiếu nại) theo lương thực tế.
  Future<void> disburseDirectly(String noticeId) async {
    final snap = await _notices.doc(noticeId).get();
    if (!snap.exists) throw Exception('Không tìm thấy yêu cầu');
    final notice = DisbursementNoticeModel.fromMap(snap.data()!, noticeId);

    if (notice.status != 'approved') {
      throw Exception('Trạng thái không hợp lệ để giải ngân.');
    }

    final grossCandidatePayment = DisbursementCalculator.grossCandidatePayment(
      notice.candidateAmounts,
    );

    // Ghi tiền vào ví từng ứng viên
    for (final entry in notice.candidateAmounts.entries) {
      if (entry.value > 0) {
        await _earningsSvc.addEarning(
          candidateId: entry.key,
          jobId: notice.jobId,
          amount: entry.value,
          details: 'Lương ca làm: ${notice.jobTitle}',
        );

        await _notif.sendToUser(
          userId: entry.key,
          title: 'Nhận tiền công',
          body:
              'NTD đã giải ngân. Bạn nhận được ${entry.value.toStringAsFixed(0)}₫ cho công việc "${notice.jobTitle}".',
          category: NotificationCategory.job,
          data: {'type': 'disbursement_received', 'jobId': notice.jobId},
        );
      }
    }

    // Cập nhật trạng thái hoàn tất
    await _notices.doc(noticeId).update({
      'status': 'completed',
      'employerAck': true,
      'completedAt': FieldValue.serverTimestamp(),
    });

    // Đóng nhóm chat (ẩn đi)
    await _closeGroup(notice.groupId);

    // Đóng bài đăng và trừ tiền ví NTD
    await _closeJobPost(
      notice.jobId,
      employerId: notice.employerId,
      totalActualPayment: grossCandidatePayment,
      jobTitle: notice.jobTitle,
    );
  }

  // ═══════════════════════════════════════════════════════
  // BƯỚC 2B: GỬI KHIẾU NẠI
  // NTD chọn ứng viên bị khiếu nại → nhập lý do + tiền đền bù → gửi Admin
  // ═══════════════════════════════════════════════════════

  /// NTD gửi khiếu nại từng ứng viên
  Future<void> submitComplaint({
    required String noticeId,
    required String candidateId,
    required String reason,
    required double compensationAmount,
    List<String> evidenceUrls = const [],
  }) async {
    final snap = await _notices.doc(noticeId).get();
    if (!snap.exists) return;
    final data = snap.data()!;

    await _notices.doc(noticeId).update({
      'status': 'complaints_pending',
      'complainedCandidates': FieldValue.arrayUnion([candidateId]),
      'deductions.$candidateId': compensationAmount,
      'complaintReasons.$candidateId': reason,
      if (evidenceUrls.isNotEmpty)
        'complaintEvidence.$candidateId': evidenceUrls,
    });

    // Thông báo cho admin
    await _notifyAdmins(
      type: 'complaint_review_needed',
      title: 'Khiếu nại mới từ NTD',
      body:
          'NTD khiếu nại ứng viên cho công việc "${data['jobTitle']}".\nLý do: $reason\nSố tiền đề xuất đền bù: ${compensationAmount.toStringAsFixed(0)}₫',
      data: {'noticeId': noticeId, 'candidateId': candidateId},
    );
  }

  // ═══════════════════════════════════════════════════════
  // ADMIN DUYỆT / TỪ CHỐI KHIẾU NẠI (sẽ làm trên web)
  // Các method này để sẵn cho backend/web gọi
  // ═══════════════════════════════════════════════════════

  /// Admin duyệt khiếu nại 1 ứng viên
  Future<void> approveDisbursementRequest(String noticeId) async {
    final snap = await _notices.doc(noticeId).get();
    if (!snap.exists) return;
    final data = snap.data()!;
    final status = data['status'] as String? ?? '';
    if (status != 'pending_admin' && status != 'approved') {
      throw Exception('Yeu cau khong con o trang thai cho duyet.');
    }

    await _notices.doc(noticeId).update({
      'status': 'approved',
      'adminAck': true,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    final employerId = data['employerId'] as String? ?? '';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final jobTitle = data['jobTitle'] as String? ?? '';

    if (employerId.isNotEmpty) {
      await _notif.create(
        recipientId: employerId,
        type: 'disbursement_approved',
        title: 'Admin da cho phep giai ngan',
        body:
            'Ban co the giai ngan ${amount.toStringAsFixed(0)}d cho "$jobTitle".',
        data: {
          'noticeId': noticeId,
          'jobId': data['jobId'],
          'groupId': data['groupId'],
        },
      );
    }
  }

  Future<void> executeDisbursement(String noticeId) =>
      disburseDirectly(noticeId);

  Future<void> rejectDisbursementRequest(
    String noticeId, {
    String? reason,
  }) async {
    final snap = await _notices.doc(noticeId).get();
    if (!snap.exists) return;
    final data = snap.data()!;

    await _notices.doc(noticeId).update({
      'status': 'rejected',
      'rejectReason': reason ?? '',
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    final employerId = data['employerId'] as String? ?? '';
    if (employerId.isNotEmpty) {
      await _notif.create(
        recipientId: employerId,
        type: 'disbursement_rejected',
        title: 'Admin tu choi giai ngan',
        body: reason?.isNotEmpty == true
            ? reason!
            : 'Lien he Admin hoac gui lai yeu cau.',
        data: {'noticeId': noticeId},
      );
    }
  }

  Future<void> adminCloseGroup({
    required String noticeId,
    required String groupId,
    required String jobId,
  }) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (groupId.isNotEmpty) {
      await _groups.doc(groupId).update({
        'status': 'closed',
        'closedBy': adminId,
        'closedAt': FieldValue.serverTimestamp(),
      });
    }

    await _closeJobPost(jobId);

    if (noticeId.isNotEmpty) {
      await _notices.doc(noticeId).update({
        'status': 'group_closed',
        'adminAck': true,
        'closedAt': FieldValue.serverTimestamp(),
      });

      final snap = await _notices.doc(noticeId).get();
      final employerId = snap.data()?['employerId'] as String? ?? '';
      if (employerId.isNotEmpty) {
        await _notif.create(
          recipientId: employerId,
          type: 'group_closed_by_admin',
          title: 'Admin da dong nhom',
          body:
              'Nhom cong viec da duoc Admin dong. Khong can giai ngan qua app.',
          data: {'groupId': groupId, 'jobId': jobId},
        );
      }
    }
  }

  Future<void> adminApproveComplaint({
    required String noticeId,
    required String candidateId,
    required double finalCompensation,
    String note = '',
  }) async {
    final snap = await _notices.doc(noticeId).get();
    if (!snap.exists) return;
    final data = snap.data()!;
    final employerId = data['employerId'] as String? ?? '';

    await _notices.doc(noticeId).update({
      'complaintResults.$candidateId': 'approved',
      'adminFinalDeductions.$candidateId': finalCompensation,
      'adminNote': note,
    });

    // Kiểm tra nếu tất cả khiếu nại đã được xem xét → chuyển trạng thái
    await _checkAllComplaintsReviewed(noticeId);

    // Thông báo cho NTD
    await _notif.create(
      recipientId: employerId,
      type: 'complaint_approved',
      title: 'Khiếu nại được duyệt',
      body:
          'Admin đã duyệt khiếu nại cho "${data['jobTitle']}". Số tiền đền bù: ${finalCompensation.toStringAsFixed(0)}₫',
      data: {'noticeId': noticeId, 'candidateId': candidateId},
    );
  }

  /// Admin từ chối khiếu nại 1 ứng viên
  Future<void> adminRejectComplaint({
    required String noticeId,
    required String candidateId,
    String note = '',
  }) async {
    final snap = await _notices.doc(noticeId).get();
    if (!snap.exists) return;
    final data = snap.data()!;
    final employerId = data['employerId'] as String? ?? '';

    await _notices.doc(noticeId).update({
      'complaintResults.$candidateId': 'rejected',
      'adminFinalDeductions.$candidateId': 0,
      'adminNote': note,
    });

    await _checkAllComplaintsReviewed(noticeId);

    await _notif.create(
      recipientId: employerId,
      type: 'complaint_rejected',
      title: 'Khiếu nại bị từ chối',
      body: 'Admin từ chối khiếu nại cho "${data['jobTitle']}". $note',
      data: {'noticeId': noticeId, 'candidateId': candidateId},
    );
  }

  /// Kiểm tra tất cả khiếu nại đã xong chưa
  Future<void> _checkAllComplaintsReviewed(String noticeId) async {
    final snap = await _notices.doc(noticeId).get();
    if (!snap.exists) return;
    final data = snap.data()!;

    final complained =
        (data['complainedCandidates'] as List?)?.cast<String>() ?? [];
    final results = data['complaintResults'] as Map? ?? {};

    if (complained.isNotEmpty && results.length >= complained.length) {
      await _notices.doc(noticeId).update({
        'status': 'complaints_reviewed',
        'complaintsReviewedAt': FieldValue.serverTimestamp(),
      });

      // Thông báo NTD
      final employerId = data['employerId'] as String? ?? '';
      await _notif.create(
        recipientId: employerId,
        type: 'all_complaints_reviewed',
        title: 'Tất cả khiếu nại đã được xử lý',
        body:
            'Admin đã xem xét xong khiếu nại cho "${data['jobTitle']}". Bạn có thể giải ngân ngay.',
        data: {'noticeId': noticeId},
      );
    }
  }

  // ═══════════════════════════════════════════════════════
  // BƯỚC 3: GIẢI NGÂN SAU KHI KHIẾU NẠI ĐƯỢC DUYỆT
  // Xử lý: trừ tiền đền bù, hoàn lại NTD, nợ nếu vượt lương
  // ═══════════════════════════════════════════════════════

  /// Giải ngân sau khi Admin đã duyệt khiếu nại
  Future<void> disburseAfterComplaint(String noticeId) async {
    final snap = await _notices.doc(noticeId).get();
    if (!snap.exists) throw Exception('Không tìm thấy yêu cầu');
    final notice = DisbursementNoticeModel.fromMap(snap.data()!, noticeId);

    if (notice.status != 'complaints_reviewed') {
      throw Exception('Chưa thể giải ngân — chờ Admin xem xét xong.');
    }

    final grossCandidatePayment = DisbursementCalculator.grossCandidatePayment(
      notice.candidateAmounts,
    );

    double totalRefundToEmployer = 0;
    final userDebts = <String, Map<String, dynamic>>{};

    for (final entry in notice.candidateAmounts.entries) {
      final cid = entry.key;
      final wage = entry.value; // tiền công của user
      final compensation =
          notice.adminFinalDeductions[cid] ?? 0; // tiền đền bù admin chốt

      if (compensation <= 0) {
        // Không bị khiếu nại hoặc khiếu nại bị từ chối → nhận đủ lương
        if (wage > 0) {
          await _earningsSvc.addEarning(
            candidateId: cid,
            jobId: notice.jobId,
            amount: wage,
            details: 'Lương ca làm: ${notice.jobTitle}',
          );

          await _notif.sendToUser(
            userId: cid,
            title: 'Nhận tiền công',
            body:
                'NTD đã giải ngân. Bạn nhận được ${wage.toStringAsFixed(0)}₫ cho công việc "${notice.jobTitle}".',
            category: NotificationCategory.job,
            data: {'type': 'disbursement_received', 'jobId': notice.jobId},
          );
        }
      } else if (compensation <= wage) {
        // Tiền đền bù <= lương → trừ từ lương, còn bao nhiêu gửi về user
        final remaining = wage - compensation;
        if (remaining > 0) {
          await _earningsSvc.addEarning(
            candidateId: cid,
            jobId: notice.jobId,
            amount: remaining,
            details:
                'Lương ca làm (sau trừ đền bù ${compensation.toStringAsFixed(0)}₫): ${notice.jobTitle}',
          );

          await _notif.sendToUser(
            userId: cid,
            title: 'Nhận tiền công (sau trừ khiếu nại)',
            body:
                'Bạn nhận được ${remaining.toStringAsFixed(0)}₫ cho công việc "${notice.jobTitle}" sau khi trừ đền bù.',
            category: NotificationCategory.job,
            data: {'type': 'disbursement_received', 'jobId': notice.jobId},
          );
        }
        totalRefundToEmployer += compensation;
      } else {
        // Tiền đền bù > lương → lương hoàn về NTD, phần chênh lệch thành nợ
        totalRefundToEmployer += wage;
        final deficit = compensation - wage;

        // Kiểm tra ví user có đủ tiền chênh lệch không
        final userBalance = await _earningsSvc.getTotalEarnings(cid);

        if (userBalance >= deficit) {
          // Ví đủ → trừ ngay
          await _earningsSvc.addEarning(
            candidateId: cid,
            jobId: notice.jobId,
            amount: -deficit,
            details: 'Trừ tiền đền bù chênh lệch cho: ${notice.jobTitle}',
          );
          totalRefundToEmployer += deficit;
        } else {
          // Ví không đủ → ghi nợ, khóa rút tiền trong 48h
          final deadline = DateTime.now().add(const Duration(hours: 48));
          userDebts[cid] = {
            'owed': deficit,
            'deadline': Timestamp.fromDate(deadline),
            'paid': false,
            'walletBalance': userBalance,
          };

          // Lấy hết tiền trong ví nếu có
          if (userBalance > 0) {
            await _earningsSvc.addEarning(
              candidateId: cid,
              jobId: notice.jobId,
              amount: -userBalance,
              details:
                  'Trừ tiền ví để đền bù (phần có thể): ${notice.jobTitle}',
            );
            totalRefundToEmployer += userBalance;
          }

          // Phần còn thiếu → thông báo user
          final stillOwed = deficit - userBalance;
          await _notif.sendToUser(
            userId: cid,
            title: 'Bạn cần chuyển tiền đền bù',
            body:
                'Bạn nợ ${stillOwed.toStringAsFixed(0)}₫ tiền đền bù cho công việc "${notice.jobTitle}". Vui lòng chuyển trong 48h, nếu không tài khoản sẽ bị khóa.',
            category: NotificationCategory.job,
            data: {
              'type': 'debt_notice',
              'noticeId': noticeId,
              'amount': stillOwed,
            },
          );

          // Khóa rút tiền cho user
          await _db.collection('users').doc(cid).update({
            'withdrawLocked': true,
            'withdrawLockedUntil': Timestamp.fromDate(deadline),
            'withdrawLockReason':
                'Chờ đền bù khiếu nại cho "${notice.jobTitle}"',
          });
        }
      }
    }

    // Ghi nhận tiền hoàn về cho NTD (tracking & wallet)
    if (totalRefundToEmployer > 0) {
      await _wallet.processComplaintRefund(
        employerId: notice.employerId,
        jobId: notice.jobId,
        amount: totalRefundToEmployer,
        description: 'Hoàn tiền đền bù từ khiếu nại: ${notice.jobTitle}',
      );

      // Gửi thông báo cho NTD
      await _notif.notifyEmployer(
        employerId: notice.employerId,
        type: 'refund',
        title: 'Hoàn tiền khiếu nại',
        body: 'Bạn đã được hoàn lại ${_money(totalRefundToEmployer)} từ khiếu nại công việc "${notice.jobTitle}".',
        category: NotificationCategory.system,
        data: {
          'type': 'refund',
          'jobId': notice.jobId,
          'amount': totalRefundToEmployer,
        },
      );
    }

    // Cập nhật trạng thái hoàn tất
    await _notices.doc(noticeId).update({
      'status': 'completed',
      'employerAck': true,
      'completedAt': FieldValue.serverTimestamp(),
      if (userDebts.isNotEmpty) 'userDebts': userDebts,
    });

    // Đóng nhóm chat (ẩn đi)
    await _closeGroup(notice.groupId);

    // Đóng bài đăng và trừ tiền ví NTD
    await _closeJobPost(
      notice.jobId,
      employerId: notice.employerId,
      totalActualPayment: grossCandidatePayment,
      jobTitle: notice.jobTitle,
    );
  }

  // ═══════════════════════════════════════════════════════
  // ĐÁNH GIÁ (SAU GIẢI NGÂN)
  // ═══════════════════════════════════════════════════════

  Future<void> submitEmployerRating({
    required String jobId,
    required String candidateId,
    required double rating,
    String? comment,
  }) async {
    final reviewerId = FirebaseAuth.instance.currentUser?.uid;
    if (reviewerId == null) return;

    final dup = await _db
        .collection('reviews')
        .where('reviewerId', isEqualTo: reviewerId)
        .where('revieweeId', isEqualTo: candidateId)
        .where('jobId', isEqualTo: jobId)
        .limit(1)
        .get();
    if (dup.docs.isNotEmpty) return;

    await _db.collection('reviews').add({
      'jobId': jobId,
      'reviewerId': reviewerId,
      'revieweeId': candidateId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Cập nhật điểm uy tín cho ứng viên
    try {
      final snap = await _db
          .collection('reviews')
          .where('revieweeId', isEqualTo: candidateId)
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
      await _db.collection('users').doc(candidateId).update({
        'averageRating': avg,
        'reviewCount': count,
      });
    } catch (_) {}

    // Thông báo cho ứng viên
    await _notif.sendToUser(
      userId: candidateId,
      title: 'Đánh giá mới từ NTD',
      body:
          'Nhà tuyển dụng đã đánh giá $rating sao cho bạn trong công việc vừa hoàn thành.',
      category: NotificationCategory.profile,
      data: {'type': 'new_review', 'jobId': jobId, 'reviewerId': reviewerId},
    );
  }

  // ═══════════════════════════════════════════════════════
  // HELPER
  // ═══════════════════════════════════════════════════════

  Future<void> _closeGroup(String groupId) async {
    if (groupId.isEmpty) return;
    try {
      await _groups.doc(groupId).update({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
      });
      // Đóng tất cả nhóm chat cùng jobId để xử lý các bản sao do lỗi tạo lặp
      final doc = await _groups.doc(groupId).get();
      final jobId = (doc.data()?['jobId'] ?? '').toString();
      if (jobId.isNotEmpty) {
        final siblings = await _groups
            .where('jobId', isEqualTo: jobId)
            .where('chatType', isEqualTo: 'group')
            .get();
        for (final s in siblings.docs) {
          if (s.id == groupId) continue;
          await s.reference.update({
            'status': 'closed',
            'closedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _closeJobPost(
    String jobId, {
    String? employerId,
    double totalActualPayment = 0.0,
    String jobTitle = '',
  }) async {
    if (jobId.isEmpty) return;
    final jobRef = _db.collection('jobPosts').doc(jobId);
    final jobSnap = await jobRef.get();
    final jobData = jobSnap.data();
    final depositHeld = (jobData?['depositStatus'] ?? '').toString() == 'held';
    final heldAmount = (jobData?['totalBudget'] as num?)?.toDouble() ?? 0;
    final unusedHeldAmount = depositHeld
        ? DisbursementCalculator.refundFromHeldBudget(
            heldAmount: heldAmount,
            grossPayment: totalActualPayment,
          )
        : 0.0;

    await jobRef.update({
      'status': 'closed',
      if (depositHeld) 'depositStatus': 'released',
      if (depositHeld) 'depositReleasedAt': FieldValue.serverTimestamp(),
      if (unusedHeldAmount > 0) 'depositRefundAmount': unusedHeldAmount,
      if (unusedHeldAmount > 0)
        'depositRefundedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (employerId != null &&
        employerId.isNotEmpty &&
        (depositHeld || totalActualPayment > 0)) {
      double walletBalanceAdjustment = 0.0;
      if (depositHeld) {
        walletBalanceAdjustment = heldAmount - totalActualPayment;
      } else {
        walletBalanceAdjustment = -totalActualPayment;
      }

      final batch = _db.batch();
      final userRef = _db.collection('users').doc(employerId);

      batch.set(userRef, {
        if (depositHeld) 'walletHeldBalance': FieldValue.increment(-heldAmount),
        'walletBalance': FieldValue.increment(walletBalanceAdjustment),
        'totalSpent': FieldValue.increment(totalActualPayment),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (totalActualPayment > 0) {
        final txRef = _db.collection('walletTransactions').doc();
        batch.set(txRef, {
          'userId': employerId,
          'type': 'payment',
          'amount': totalActualPayment,
          'description': 'Thanh toán tiền công cho "$jobTitle"',
          'status': 'completed',
          'paymentMethod': 'wallet',
          'jobId': jobId,
          'createdAt': FieldValue.serverTimestamp(),
          'completedAt': FieldValue.serverTimestamp(),
        });
      }

      if (unusedHeldAmount > 0) {
        final refundRef = _db.collection('walletTransactions').doc();
        batch.set(refundRef, {
          'userId': employerId,
          'type': 'refund',
          'amount': unusedHeldAmount,
          'description': 'Hoàn tiền ứng dư cho "$jobTitle"',
          'status': 'completed',
          'paymentMethod': 'wallet',
          'jobId': jobId,
          'createdAt': FieldValue.serverTimestamp(),
          'completedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }
  }

  Future<void> _notifyAdmins({
    required String type,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final admins = await _db
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .limit(15)
        .get();
    for (final admin in admins.docs) {
      await _notif.create(
        recipientId: admin.id,
        type: type,
        title: title,
        body: body,
        data: data,
      );
    }
  }

  // ═══════════════════════════════════════════════════════
  // ADMIN: Query cho web (để sẵn)
  // ═══════════════════════════════════════════════════════

  Future<List<DisbursementNoticeModel>> listPendingForAdmin() async {
    final snap = await _notices
        .where('status', whereIn: ['pending_admin', 'complaints_pending'])
        .limit(50)
        .get();
    return snap.docs
        .map((d) => DisbursementNoticeModel.fromMap(d.data(), d.id))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
