import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/application_model.dart';
import '../models/job_post_model.dart';
import 'group_chat_service.dart';
import 'notification_service.dart';
import 'schedule_lock_service.dart';

class AcceptApplicationResult {
  final Set<String> autoRejectedAppIds;

  const AcceptApplicationResult({this.autoRejectedAppIds = const <String>{}});
}

class CandidatesService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _groupChat = GroupChatService();
  final _scheduleLocks = ScheduleLockService();

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
      allApps.addAll(
        snap.docs.map((d) {
          final data = d.data();
          data['appId'] = d.id;
          return ApplicationModel.fromMap(data);
        }),
      );
    }

    if (allApps.isEmpty) {
      return jobs.map((j) => JobWithApplications(job: j, entries: [])).toList();
    }

    final jobsById = {for (final job in jobs) job.jobId: job};
    final expiredRejectedIds = await _rejectExpiredPendingApplications(
      jobsById: jobsById,
      apps: allApps,
    );
    if (expiredRejectedIds.isNotEmpty) {
      for (var i = 0; i < allApps.length; i++) {
        if (expiredRejectedIds.contains(allApps[i].appId)) {
          allApps[i] = allApps[i].copyWith(status: 'rejected');
        }
      }
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

    appsByJob.forEach((_, entries) {
      entries.sort(_compareByAppliedAtAsc);
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

    entries.sort(_compareByAppliedAtAsc);
    return entries;
  }

  int _compareByAppliedAtAsc(ApplicationEntry a, ApplicationEntry b) {
    final aTime = a.application.appliedAt ?? a.application.updatedAt;
    final bTime = b.application.appliedAt ?? b.application.updatedAt;
    if (aTime == null && bTime == null) {
      return a.candidate.fullName.compareTo(b.candidate.fullName);
    }
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    final timeCompare = aTime.compareTo(bTime);
    if (timeCompare != 0) return timeCompare;
    return a.candidate.fullName.compareTo(b.candidate.fullName);
  }

  bool _isApplicationDeadlineEnded(JobPostModel job, DateTime now) {
    final deadline = job.applicationDeadline;
    return deadline != null && !deadline.isAfter(now);
  }

  Future<Set<String>> _rejectExpiredPendingApplications({
    required Map<String, JobPostModel> jobsById,
    required List<ApplicationModel> apps,
  }) async {
    final now = DateTime.now();
    final toReject = apps.where((app) {
      if (app.status != 'pending') return false;
      final job = jobsById[app.jobId];
      if (job == null) return false;
      return _isApplicationDeadlineEnded(job, now);
    }).toList();

    if (toReject.isEmpty) return const <String>{};
    await _rejectPendingApps(toReject, jobsById, reason: 'deadline');
    return toReject.map((app) => app.appId).toSet();
  }

  Future<void> _rejectPendingApps(
    List<ApplicationModel> apps,
    Map<String, JobPostModel> jobsById, {
    required String reason,
  }) async {
    if (apps.isEmpty) return;

    for (var i = 0; i < apps.length; i += 450) {
      final end = (i + 450).clamp(0, apps.length);
      final batch = _db.batch();
      for (final app in apps.sublist(i, end)) {
        batch.update(_db.collection('applications').doc(app.appId), {
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    for (final app in apps) {
      final job = jobsById[app.jobId];
      try {
        await NotificationService.notifyApplicationRejected(
          candidateId: app.candidateId,
          jobTitle: job?.title ?? 'Công việc',
          jobId: app.jobId,
          reason: reason,
        );
      } catch (_) {}
    }
  }

  // ── Duyệt đơn: set status='accepted' + tăng filledSlots ─────────────────
  Future<AcceptApplicationResult> acceptApplication(
    String appId,
    String jobId,
  ) async {
    final appRef = _db.collection('applications').doc(appId);
    final jobRef = _db.collection('jobPosts').doc(jobId);
    late Map<String, dynamic> appData;
    late Map<String, dynamic> jobData;
    late JobPostModel acceptedJob;
    late String candidateId;
    late String employerId;
    late String jobTitle;

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
      acceptedJob = JobPostModel.fromMap({...jobData, 'jobId': jobSnap.id});
      candidateId = (appData['candidateId'] ?? '').toString();
      employerId = (appData['employerId'] ?? acceptedJob.employerId).toString();
      jobTitle = (jobData['title'] ?? acceptedJob.title).toString();

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

      if (candidateId.isEmpty) {
        throw Exception('Thiếu thông tin ứng viên.');
      }

      await _scheduleLocks.acquireLocksInTransaction(
        tx: tx,
        candidateId: candidateId,
        appId: appId,
        jobId: jobId,
        employerId: employerId,
        jobTitle: jobTitle,
        windows: ScheduleLockService.buildShiftWindows(acceptedJob),
      );

      tx.update(appRef, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(jobRef, {
        'filledSlots': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    final jobType = (jobData['jobType'] ?? 'part_time').toString();
    Set<String> autoRejectedAppIds = const <String>{};
    try {
      autoRejectedAppIds = await _rejectPendingApplicationsOverlappingJob(
        candidateId: candidateId,
        acceptedAppId: appId,
        acceptedJob: acceptedJob,
      );
    } catch (_) {}

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

    return AcceptApplicationResult(autoRejectedAppIds: autoRejectedAppIds);
  }

  // ── Từ chối đơn ─────────────────────────────────────────────────────────
  Future<Set<String>> _rejectPendingApplicationsOverlappingJob({
    required String candidateId,
    required String acceptedAppId,
    required JobPostModel acceptedJob,
  }) async {
    if (candidateId.isEmpty) return const <String>{};

    final pendingSnap = await _db
        .collection('applications')
        .where('candidateId', isEqualTo: candidateId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (pendingSnap.docs.isEmpty) return const <String>{};

    final pendingApps = pendingSnap.docs
        .map((doc) {
          final data = doc.data();
          data['appId'] = doc.id;
          return ApplicationModel.fromMap(data);
        })
        .where(
          (app) => app.appId != acceptedAppId && app.jobId != acceptedJob.jobId,
        )
        .toList();
    if (pendingApps.isEmpty) return const <String>{};

    final jobIds = pendingApps.map((app) => app.jobId).toSet().toList();
    final jobsById = <String, JobPostModel>{};
    for (var i = 0; i < jobIds.length; i += 30) {
      final end = (i + 30).clamp(0, jobIds.length);
      final batch = jobIds.sublist(i, end);
      final jobsSnap = await _db
          .collection('jobPosts')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in jobsSnap.docs) {
        jobsById[doc.id] = JobPostModel.fromMap({
          ...doc.data(),
          'jobId': doc.id,
        });
      }
    }

    final toReject = pendingApps.where((app) {
      final job = jobsById[app.jobId];
      if (job == null) return false;
      return ScheduleLockService.jobsOverlap(acceptedJob, job);
    }).toList();
    if (toReject.isEmpty) return const <String>{};

    await _rejectPendingApps(toReject, jobsById, reason: 'schedule_conflict');
    return toReject.map((app) => app.appId).toSet();
  }

  Future<void> rejectApplication(String appId) async {
    final appRef = _db.collection('applications').doc(appId);
    final appSnap = await appRef.get();
    if (!appSnap.exists) {
      throw Exception('Không tìm thấy đơn ứng tuyển.');
    }

    final appData = appSnap.data() ?? {};
    final status = (appData['status'] ?? '').toString();
    if (status != 'pending') {
      throw Exception('Đơn ứng tuyển đã được xử lý.');
    }

    final app = ApplicationModel.fromMap({...appData, 'appId': appSnap.id});
    final jobSnap = await _db.collection('jobPosts').doc(app.jobId).get();
    final job = jobSnap.exists
        ? JobPostModel.fromMap({...jobSnap.data()!, 'jobId': jobSnap.id})
        : null;

    await appRef.update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await NotificationService.notifyApplicationRejected(
        candidateId: app.candidateId,
        jobTitle: job?.title ?? 'Công việc',
        jobId: app.jobId,
        reason: 'manual',
      );
    } catch (_) {}
  }

  Future<int> rejectRemainingPendingApplications(String jobId) async {
    final jobSnap = await _db.collection('jobPosts').doc(jobId).get();
    if (!jobSnap.exists) {
      throw Exception('Không tìm thấy công việc.');
    }

    final job = JobPostModel.fromMap({...jobSnap.data()!, 'jobId': jobSnap.id});
    final snap = await _db
        .collection('applications')
        .where('jobId', isEqualTo: jobId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (snap.docs.isEmpty) return 0;

    final apps = snap.docs.map((doc) {
      final data = doc.data();
      data['appId'] = doc.id;
      return ApplicationModel.fromMap(data);
    }).toList();
    await _rejectPendingApps(apps, {job.jobId: job}, reason: 'job_full');
    return apps.length;
  }

  // ── Huỷ duyệt (accepted → pending), giảm filledSlots ────────────────────
  Future<void> revokeAcceptance(String appId, String jobId) async {
    final appRef = _db.collection('applications').doc(appId);
    final jobRef = _db.collection('jobPosts').doc(jobId);

    await _db.runTransaction((tx) async {
      final appSnap = await tx.get(appRef);
      final jobSnap = await tx.get(jobRef);
      if (!appSnap.exists) {
        throw Exception('Không tìm thấy đơn ứng tuyển.');
      }
      if (!jobSnap.exists) {
        throw Exception('Không tìm thấy công việc.');
      }

      final appData = appSnap.data() ?? {};
      if ((appData['status'] ?? '').toString() != 'accepted') {
        throw Exception('Chỉ có thể hủy duyệt đơn đã được chấp nhận.');
      }

      final job = JobPostModel.fromMap({
        ...jobSnap.data()!,
        'jobId': jobSnap.id,
      });
      await _scheduleLocks.releaseLocksInTransaction(
        tx: tx,
        candidateId: (appData['candidateId'] ?? '').toString(),
        appId: appId,
        windows: ScheduleLockService.buildShiftWindows(job),
      );

      tx.update(appRef, {
        'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(jobRef, {
        'filledSlots': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
