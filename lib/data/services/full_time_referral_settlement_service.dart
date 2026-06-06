import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/app_notification_model.dart';
import '../models/job_post_model.dart';
import 'job_pricing_service.dart';
import 'notification_service.dart';

class FullTimeReferralSettlementResult {
  final int acceptedCount;
  final double commissionAmount;
  final double refundAmount;
  final double heldAmount;
  final String finalStatus;
  final bool settledMoney;
  final bool alreadySettled;

  const FullTimeReferralSettlementResult({
    required this.acceptedCount,
    required this.commissionAmount,
    required this.refundAmount,
    required this.heldAmount,
    required this.finalStatus,
    required this.settledMoney,
    required this.alreadySettled,
  });
}

class FullTimeReferralSettlementService {
  FullTimeReferralSettlementService();

  final _db = FirebaseFirestore.instance;
  final _notifications = NotificationService();

  Future<FullTimeReferralSettlementResult?> settleAfterDeadline(
    JobPostModel job,
  ) {
    return _process(
      jobId: job.jobId,
      trigger: 'deadline',
      requestedStatus: 'closed',
      requireDeadlineEnded: true,
      notifyAcceptedCandidates: true,
    );
  }

  Future<FullTimeReferralSettlementResult?> closeOrDeleteJob(
    String jobId, {
    required String requestedStatus,
    String trigger = 'manual',
  }) {
    return _process(
      jobId: jobId,
      trigger: trigger,
      requestedStatus: requestedStatus,
      requireDeadlineEnded: false,
      notifyAcceptedCandidates: true,
    );
  }

  Future<FullTimeReferralSettlementResult?> _process({
    required String jobId,
    required String trigger,
    required String requestedStatus,
    required bool requireDeadlineEnded,
    required bool notifyAcceptedCandidates,
  }) async {
    if (jobId.isEmpty) return null;

    final jobRef = _db.collection('jobPosts').doc(jobId);
    final firstJobSnap = await jobRef.get();
    if (!firstJobSnap.exists) return null;
    final firstJob = JobPostModel.fromMap({
      ...firstJobSnap.data()!,
      'jobId': firstJobSnap.id,
    });
    if (!firstJob.isFullTimeReferral) return null;
    if (requireDeadlineEnded && !_isActiveJob(firstJob)) return null;
    if (requireDeadlineEnded) {
      final deadline = firstJob.applicationDeadline;
      if (deadline == null || deadline.isAfter(DateTime.now())) return null;
    }

    final appsSnap = await _db
        .collection('applications')
        .where('jobId', isEqualTo: jobId)
        .get();
    final acceptedDocs = appsSnap.docs.where((doc) {
      return (doc.data()['status'] ?? '').toString() == 'accepted';
    }).toList();
    final pendingDocs = appsSnap.docs.where((doc) {
      return (doc.data()['status'] ?? '').toString() == 'pending';
    }).toList();
    final acceptedCount = acceptedDocs.length > firstJob.slots
        ? firstJob.slots
        : acceptedDocs.length;

    final result = await _db.runTransaction<FullTimeReferralSettlementResult?>((
      tx,
    ) async {
      final jobSnap = await tx.get(jobRef);
      if (!jobSnap.exists) return null;
      final latestJob = JobPostModel.fromMap({
        ...jobSnap.data()!,
        'jobId': jobSnap.id,
      });
      if (!latestJob.isFullTimeReferral) return null;
      if (requireDeadlineEnded && !_isActiveJob(latestJob)) return null;

      if (requireDeadlineEnded) {
        final deadline = latestJob.applicationDeadline;
        if (deadline == null || deadline.isAfter(DateTime.now())) return null;
      }

      final finalStatus = requestedStatus == 'deleted' && acceptedCount > 0
          ? 'closed'
          : requestedStatus;
      final logRef = jobRef
          .collection('workflowReminders')
          .doc('full_time_referral_settlement');
      final logSnap = await tx.get(logRef);
      final alreadySettled =
          logSnap.exists || latestJob.depositStatus != 'held';
      final heldAmount = latestJob.totalBudget > 0
          ? latestJob.totalBudget
          : JobPricingService.fullTimeReferralFeePerSlot * latestJob.slots;
      final rawCommission =
          JobPricingService.fullTimeReferralFeePerSlot * acceptedCount;
      final commissionAmount = rawCommission > heldAmount
          ? heldAmount
          : rawCommission;
      final refundAmount = heldAmount - commissionAmount;

      final jobUpdates = <String, dynamic>{
        'status': finalStatus,
        'filledSlots': acceptedCount,
        'updatedAt': FieldValue.serverTimestamp(),
        if (finalStatus == 'closed') 'closedAt': FieldValue.serverTimestamp(),
        if (finalStatus == 'deleted') 'deletedAt': FieldValue.serverTimestamp(),
        if (requestedStatus == 'deleted' && acceptedCount > 0)
          'deleteRequestedAt': FieldValue.serverTimestamp(),
      };

      var settledMoney = false;
      if (!alreadySettled && latestJob.depositStatus == 'held') {
        settledMoney = true;
        final userRef = _db.collection('users').doc(latestJob.employerId);
        tx.set(userRef, {
          'walletHeldBalance': FieldValue.increment(-heldAmount),
          if (refundAmount > 0)
            'walletBalance': FieldValue.increment(refundAmount),
          if (commissionAmount > 0)
            'totalSpent': FieldValue.increment(commissionAmount),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (commissionAmount > 0) {
          final commissionTxRef = _db
              .collection('walletTransactions')
              .doc('full_time_referral_fee_$jobId');
          tx.set(commissionTxRef, {
            'userId': latestJob.employerId,
            'type': 'full_time_referral_fee',
            'amount': commissionAmount,
            'description':
                'Phí giới thiệu Full-time cho bài đăng "${latestJob.title}"',
            'status': 'completed',
            'paymentMethod': 'wallet_hold',
            'jobId': jobId,
            'acceptedCount': acceptedCount,
            'feePerSlot': JobPricingService.fullTimeReferralFeePerSlot,
            'trigger': trigger,
            'idempotencyKey': 'full_time_referral_fee_$jobId',
            'createdAt': FieldValue.serverTimestamp(),
            'completedAt': FieldValue.serverTimestamp(),
          });
        }

        if (refundAmount > 0) {
          final refundTxRef = _db
              .collection('walletTransactions')
              .doc('full_time_referral_refund_$jobId');
          tx.set(refundTxRef, {
            'userId': latestJob.employerId,
            'type': 'refund',
            'amount': refundAmount,
            'description':
                'Hoàn phí giới thiệu Full-time chưa dùng cho bài đăng "${latestJob.title}"',
            'status': 'completed',
            'paymentMethod': 'wallet',
            'jobId': jobId,
            'acceptedCount': acceptedCount,
            'feePerSlot': JobPricingService.fullTimeReferralFeePerSlot,
            'trigger': trigger,
            'idempotencyKey': 'full_time_referral_refund_$jobId',
            'createdAt': FieldValue.serverTimestamp(),
            'completedAt': FieldValue.serverTimestamp(),
          });
        }

        final calculation = <String, dynamic>{
          ...?latestJob.depositCalculation,
          'acceptedCount': acceptedCount,
          'commissionAmount': commissionAmount,
          'refundAmount': refundAmount,
          'settlementUnit': 'full_time_referral_fee',
          'settlementTrigger': trigger,
        };
        jobUpdates.addAll({
          'depositStatus': acceptedCount == 0 ? 'refunded' : 'released',
          if (acceptedCount > 0)
            'depositReleasedAt': FieldValue.serverTimestamp(),
          if (refundAmount > 0 || acceptedCount == 0)
            'depositRefundedAt': FieldValue.serverTimestamp(),
          'depositRefundAmount': refundAmount,
          'depositCompensationAmount': commissionAmount,
          'referralAcceptedCount': acceptedCount,
          'referralCommissionAmount': commissionAmount,
          'referralRefundAmount': refundAmount,
          'referralSettledAt': FieldValue.serverTimestamp(),
          'depositCalculation': calculation,
        });
        tx.set(logRef, {
          'settledAt': FieldValue.serverTimestamp(),
          'trigger': trigger,
          'requestedStatus': requestedStatus,
          'finalStatus': finalStatus,
          'acceptedCount': acceptedCount,
          'commissionAmount': commissionAmount,
          'refundAmount': refundAmount,
          'heldAmount': heldAmount,
        }, SetOptions(merge: true));
      } else if (!logSnap.exists) {
        tx.set(logRef, {
          'skippedAt': FieldValue.serverTimestamp(),
          'trigger': trigger,
          'reason': 'deposit_not_held',
          'depositStatus': latestJob.depositStatus,
        }, SetOptions(merge: true));
      }

      tx.update(jobRef, jobUpdates);

      return FullTimeReferralSettlementResult(
        acceptedCount: acceptedCount,
        commissionAmount: commissionAmount,
        refundAmount: refundAmount,
        heldAmount: heldAmount,
        finalStatus: finalStatus,
        settledMoney: settledMoney,
        alreadySettled: alreadySettled,
      );
    });

    if (result == null) return null;
    await _rejectPendingApplications(pendingDocs, firstJob, trigger);
    if (notifyAcceptedCandidates && acceptedDocs.isNotEmpty) {
      await _notifyAcceptedCandidates(acceptedDocs, firstJob, result);
    }
    await _notifyEmployer(firstJob, result);
    return result;
  }

  Future<void> _rejectPendingApplications(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    JobPostModel job,
    String trigger,
  ) async {
    if (docs.isEmpty) return;
    for (var i = 0; i < docs.length; i += 450) {
      final end = (i + 450).clamp(0, docs.length);
      final batch = _db.batch();
      for (final doc in docs.sublist(i, end)) {
        batch.update(doc.reference, {
          'status': 'rejected',
          'rejectReason': 'full_time_$trigger',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    for (final doc in docs) {
      final candidateId = (doc.data()['candidateId'] ?? '').toString();
      try {
        await NotificationService.notifyApplicationRejected(
          candidateId: candidateId,
          jobTitle: job.title,
          jobId: job.jobId,
          reason: 'job_closed',
        );
      } catch (_) {}
    }
  }

  Future<void> _notifyAcceptedCandidates(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    JobPostModel job,
    FullTimeReferralSettlementResult result,
  ) async {
    for (final doc in docs) {
      final candidateId = (doc.data()['candidateId'] ?? '').toString();
      if (candidateId.isEmpty) continue;
      try {
        await NotificationService.notifyFullTimeAcceptedJobClosed(
          candidateId: candidateId,
          jobTitle: job.title,
          jobId: job.jobId,
          interviewAt: _interviewAtFor(job),
        );
      } catch (_) {}
    }
  }

  Future<void> _notifyEmployer(
    JobPostModel job,
    FullTimeReferralSettlementResult result,
  ) async {
    final title = result.acceptedCount == 0
        ? 'Đã hoàn phí giới thiệu Full-time'
        : 'Đã quyết toán phí giới thiệu Full-time';
    final body = result.acceptedCount == 0
        ? '"${job.title}": chưa có ứng viên được duyệt. ViecNow hoàn ${_money(result.refundAmount)}.'
        : '"${job.title}": ${result.acceptedCount} ứng viên đã được duyệt. '
              'ViecNow thu ${_money(result.commissionAmount)}, '
              'hoàn ${_money(result.refundAmount)}.';
    await _notifications.notifyEmployer(
      employerId: job.employerId,
      type: 'full_time_referral_settled',
      title: title,
      body: body,
      category: NotificationCategory.job,
      data: {
        'type': 'full_time_referral_settled',
        'jobId': job.jobId,
        'acceptedCount': result.acceptedCount,
        'commissionAmount': result.commissionAmount,
        'refundAmount': result.refundAmount,
        'finalStatus': result.finalStatus,
      },
    );
  }

  DateTime _interviewAtFor(JobPostModel job) {
    final parts = (job.startTime ?? '').split(':');
    if (parts.length < 2) return job.startDate;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return job.startDate;
    return DateTime(
      job.startDate.year,
      job.startDate.month,
      job.startDate.day,
      hour,
      minute,
    );
  }

  String _money(double value) {
    return '${NumberFormat('#,###', 'vi_VN').format(value.ceil())}đ';
  }

  bool _isActiveJob(JobPostModel job) {
    return job.status == 'approved' || job.status == 'active';
  }
}
