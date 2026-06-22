import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../data/services/job_workflow_service.dart';
import '../data/services/profanity_filter_service.dart';

class CandidateToEvaluate {
  final String jobId;
  final String jobTitle;
  final String candidateId;
  final String candidateName;
  final String? candidateAvatarUrl;
  bool isReviewed;

  CandidateToEvaluate({
    required this.jobId,
    required this.jobTitle,
    required this.candidateId,
    required this.candidateName,
    this.candidateAvatarUrl,
    this.isReviewed = false,
  });
}

class EmployerEvaluateCandidatesController extends GetxController {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _workflow = JobWorkflowService();

  final RxList<CandidateToEvaluate> candidates = <CandidateToEvaluate>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadCandidates();
  }

  Future<void> loadCandidates() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    isLoading.value = true;
    try {
      // 1. Fetch completed disbursements for this employer
      final noticesSnap = await _db
          .collection('disbursementNotices')
          .where('employerId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .get();

      final list = <CandidateToEvaluate>[];
      final candidateIdsToFetch = <String>{};
      
      // We will need to check existing reviews by this employer
      final reviewsSnap = await _db
          .collection('reviews')
          .where('reviewerId', isEqualTo: uid)
          .get();
          
      // Map to quickly check if a review exists for a (jobId, candidateId)
      final reviewMap = <String, bool>{};
      for (final doc in reviewsSnap.docs) {
        final d = doc.data();
        final jId = d['jobId'] as String? ?? '';
        final cId = d['revieweeId'] as String? ?? '';
        reviewMap['${jId}_$cId'] = true;
      }

      // Group notices by groupId to avoid redundant fetches
      for (final noticeDoc in noticesSnap.docs) {
        final notice = noticeDoc.data();
        final groupId = notice['groupId'] as String? ?? '';
        final jobId = notice['jobId'] as String? ?? '';
        final jobTitle = notice['jobTitle'] as String? ?? 'Công việc';

        if (groupId.isEmpty) continue;

        // Fetch group to get memberIds
        final groupSnap = await _db.collection('groupChats').doc(groupId).get();
        if (!groupSnap.exists) continue;

        final groupData = groupSnap.data()!;
        final memberIds = List<String>.from(groupData['memberIds'] ?? []);
        
        for (final mId in memberIds) {
          if (mId != uid && mId.isNotEmpty) {
            candidateIdsToFetch.add(mId);
            list.add(CandidateToEvaluate(
              jobId: jobId,
              jobTitle: jobTitle,
              candidateId: mId,
              candidateName: 'Đang tải...', // will update later
              isReviewed: reviewMap['${jobId}_$mId'] ?? false,
            ));
          }
        }
      }

      // 2. Fetch candidate profiles
      final profilesMap = <String, Map<String, dynamic>>{};
      if (candidateIdsToFetch.isNotEmpty) {
        final uidList = candidateIdsToFetch.toList();
        final chunks = <List<String>>[];
        for (var i = 0; i < uidList.length; i += 30) {
          chunks.add(uidList.sublist(
              i, i + 30 > uidList.length ? uidList.length : i + 30));
        }

        for (final chunk in chunks) {
          try {
            final snap = await _db
                .collection('users')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
            for (final doc in snap.docs) {
              profilesMap[doc.id] = doc.data();
            }
          } catch (_) {}
        }
      }

      // 3. Update names and avatars
      for (var i = 0; i < list.length; i++) {
        final p = profilesMap[list[i].candidateId];
        if (p != null) {
          final fName = p['firstName'] as String? ?? '';
          final lName = p['lastName'] as String? ?? '';
          list[i] = CandidateToEvaluate(
            jobId: list[i].jobId,
            jobTitle: list[i].jobTitle,
            candidateId: list[i].candidateId,
            candidateName: '$fName $lName'.trim().isEmpty ? 'Người dùng' : '$fName $lName'.trim(),
            candidateAvatarUrl: p['avatarUrl'] as String?,
            isReviewed: list[i].isReviewed,
          );
        }
      }

      // Sort: Not reviewed first
      list.sort((a, b) {
        if (a.isReviewed && !b.isReviewed) return 1;
        if (!a.isReviewed && b.isReviewed) return -1;
        return 0;
      });

      candidates.assignAll(list);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải danh sách ứng viên');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> submitRating(String jobId, String candidateId, double rating, String comment) async {
    isLoading.value = true;
    try {
      if (ProfanityFilterService.containsProfanity(comment)) {
        throw Exception('Nhận xét chứa từ ngữ không phù hợp.');
      }
      await _workflow.submitEmployerRating(
        jobId: jobId,
        candidateId: candidateId,
        rating: rating,
        comment: comment,
      );
      // Update local state
      final idx = candidates.indexWhere((c) => c.jobId == jobId && c.candidateId == candidateId);
      if (idx != -1) {
        final c = candidates[idx];
        c.isReviewed = true;
        candidates[idx] = c;
      }
      Get.snackbar('Thành công', 'Đã đánh giá ứng viên', backgroundColor: Get.theme.primaryColor, colorText: Get.theme.colorScheme.onPrimary);
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}
