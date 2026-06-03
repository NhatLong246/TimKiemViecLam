import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/application_model.dart';
import '../models/job_post_model.dart';
import 'group_chat_service.dart';
import 'notification_service.dart';

class CandidatesService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _groupChat = GroupChatService();

  // ── Fetch tất cả job theo loại + đơn ứng tuyển của employer ──────────────
  /// Trả về danh sách job (theo jobType) kèm đơn ứng tuyển đã join với thông
  /// tin ứng viên. Thực hiện 3 round-trip (jobs → applications → users).
  Future<List<JobWithApplications>> fetchByJobType(String jobType) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    // 1. Lấy job của employer theo loại (active/approved/closed)
    final jobsSnap = await _db
        .collection('jobPosts')
        .where('employerId', isEqualTo: uid)
        .where('jobType', isEqualTo: jobType)
        .get();

    if (jobsSnap.docs.isEmpty) return [];

    final jobs =
        jobsSnap.docs.map((d) => JobPostModel.fromMap(d.data())).toList()
          ..sort((a, b) {
            final aTime = a.createdAt;
            final bTime = b.createdAt;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

    final jobIds = jobs.map((j) => j.jobId).toList();

    // 2. Lấy tất cả đơn ứng tuyển cho các job này (batch 30 do Firestore limit)
    final List<ApplicationModel> allApps = [];
    for (var i = 0; i < jobIds.length; i += 30) {
      final end = (i + 30).clamp(0, jobIds.length);
      final batch = jobIds.sublist(i, end);
      final snap = await _db
          .collection('applications')
          .where('jobId', whereIn: batch)
          .get();
      allApps.addAll(snap.docs.map((d) {
        final data = d.data();
        data['appId'] = d.id;
        return ApplicationModel.fromMap(data);
      }));
    }

    if (allApps.isEmpty) {
      return jobs.map((j) => JobWithApplications(job: j, entries: [])).toList();
    }

    // 3. Lấy thông tin ứng viên (batch 30)
    final candidateIds = allApps.map((a) => a.candidateId).toSet().toList();
    final Map<String, CandidateSnapshot> candidateMap = {};
    for (var i = 0; i < candidateIds.length; i += 30) {
      final end = (i + 30).clamp(0, candidateIds.length);
      final batch = candidateIds.sublist(i, end);
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snap.docs) {
        candidateMap[doc.id] = CandidateSnapshot.fromMap(doc.id, doc.data());
      }
    }

    // 4. Group đơn theo jobId
    final Map<String, List<ApplicationEntry>> appsByJob = {};
    for (final app in allApps) {
      final candidate = candidateMap[app.candidateId];
      if (candidate == null) continue; // bỏ qua nếu user đã bị xóa
      if (!candidate.isCandidate) continue; // chỉ cho phép ứng viên thật
      if (app.candidateId == app.employerId) continue; // chặn tự ứng tuyển
      appsByJob
          .putIfAbsent(app.jobId, () => [])
          .add(ApplicationEntry(application: app, candidate: candidate));
    }

    // 5. Sort entries: pending → accepted → rejected → withdrawn
    const statusOrder = {
      'pending': 0,
      'accepted': 1,
      'rejected': 2,
      'withdrawn': 3,
    };
    appsByJob.forEach((_, entries) {
      entries.sort(
        (a, b) => (statusOrder[a.application.status] ?? 4).compareTo(
          statusOrder[b.application.status] ?? 4,
        ),
      );
    });

    return jobs.map((job) {
      return JobWithApplications(job: job, entries: appsByJob[job.jobId] ?? []);
    }).toList();
  }

  Future<List<ApplicationEntry>> fetchAcceptedByJob(JobPostModel job) async {
    final snap = await _db
        .collection('applications')
        .where('jobId', isEqualTo: job.jobId)
        .get();

    final apps = snap.docs
        .map((d) => ApplicationModel.fromMap(d.data()))
        .where((app) => app.status == 'accepted')
        .toList();
    if (apps.isEmpty) return [];

    final candidateIds = apps.map((a) => a.candidateId).toSet().toList();
    final Map<String, CandidateSnapshot> candidateMap = {};
    for (var i = 0; i < candidateIds.length; i += 30) {
      final end = (i + 30).clamp(0, candidateIds.length);
      final batch = candidateIds.sublist(i, end);
      final usersSnap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in usersSnap.docs) {
        candidateMap[doc.id] = CandidateSnapshot.fromMap(doc.id, doc.data());
      }
    }

    final entries = <ApplicationEntry>[];
    for (final app in apps) {
      final candidate = candidateMap[app.candidateId];
      if (candidate == null) continue;
      if (!candidate.isCandidate) continue;
      if (app.candidateId == app.employerId) continue;
      entries.add(ApplicationEntry(application: app, candidate: candidate));
    }

    entries.sort((a, b) {
      final aTime = a.application.updatedAt ?? a.application.appliedAt;
      final bTime = b.application.updatedAt ?? b.application.appliedAt;
      if (aTime == null && bTime == null) {
        return a.candidate.fullName.compareTo(b.candidate.fullName);
      }
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return entries;
  }

  // ── Duyệt đơn: set status='accepted' + tăng filledSlots ─────────────────
  Future<void> acceptApplication(String appId, String jobId) async {
    final appRef = _db.collection('applications').doc(appId);
    final jobRef = _db.collection('jobPosts').doc(jobId);
    late Map<String, dynamic> appData;
    late Map<String, dynamic> jobData;

    await _db.runTransaction((tx) async {
      final appSnap = await tx.get(appRef);
      final jobSnap = await tx.get(jobRef);
      if (!appSnap.exists) {
        throw Exception('Không tìm thấy đơn ứng tuyển.');
      }
      if (!jobSnap.exists) {
        throw Exception('Không tìm thấy công việc.');
      }

      appData = appSnap.data() ?? {};
      jobData = jobSnap.data() ?? {};

      final appStatus = (appData['status'] ?? '').toString();
      if (appStatus != 'pending') {
        throw Exception('Đơn ứng tuyển đã được xử lý.');
      }

      final jobStatus = (jobData['status'] ?? '').toString();
      if (jobStatus != 'approved' && jobStatus != 'active') {
        throw Exception('Công việc hiện không thể duyệt thêm ứng viên.');
      }

      final slots = (jobData['slots'] as num?)?.toInt() ?? 0;
      final filledSlots = (jobData['filledSlots'] as num?)?.toInt() ?? 0;
      if (slots <= 0 || filledSlots >= slots) {
        throw Exception('Công việc đã đủ số lượng ứng viên.');
      }

      tx.update(appRef, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(jobRef, {
        'filledSlots': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    final jobTitle = (jobData['title'] ?? 'Công việc').toString();
    final jobType = (jobData['jobType'] ?? 'part_time').toString();
    final candidateId = (appData['candidateId'] ?? '').toString();
    final employerId = (appData['employerId'] ?? '').toString();

    if (candidateId.isNotEmpty && employerId.isNotEmpty) {
      if (jobType != 'full_time') {
        await _groupChat.ensureJobGroup(
          jobId: jobId,
          jobTitle: jobTitle,
          employerId: employerId,
          candidateId: candidateId,
        );
      }
      await NotificationService.notifyApplicationAccepted(
        candidateId: candidateId,
        jobTitle: jobTitle,
        isFullTimeReferral: jobType == 'full_time',
      );
    }
  }

  // ── Từ chối đơn ─────────────────────────────────────────────────────────
  Future<void> rejectApplication(String appId) async {
    await _db.collection('applications').doc(appId).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Huỷ duyệt (accepted → pending), giảm filledSlots ────────────────────
  Future<void> revokeAcceptance(String appId, String jobId) async {
    final batch = _db.batch();
    batch.update(_db.collection('applications').doc(appId), {
      'status': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('jobPosts').doc(jobId), {
      'filledSlots': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
