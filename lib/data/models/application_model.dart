import 'package:cloud_firestore/cloud_firestore.dart';
import 'job_post_model.dart';

class ApplicationModel {
  final String appId;
  final String jobId;
  final String candidateId;
  final String employerId;
  final String status; // "pending"|"accepted"|"rejected"|"withdrawn"
  final String? cvUrl;
  final String? coverLetter;
  final DateTime? appliedAt;
  final DateTime? updatedAt;

  const ApplicationModel({
    required this.appId,
    required this.jobId,
    required this.candidateId,
    required this.employerId,
    required this.status,
    this.cvUrl,
    this.coverLetter,
    this.appliedAt,
    this.updatedAt,
  });

  ApplicationModel copyWith({
    String? appId,
    String? jobId,
    String? candidateId,
    String? employerId,
    String? status,
    String? cvUrl,
    String? coverLetter,
    DateTime? appliedAt,
    DateTime? updatedAt,
  }) {
    return ApplicationModel(
      appId: appId ?? this.appId,
      jobId: jobId ?? this.jobId,
      candidateId: candidateId ?? this.candidateId,
      employerId: employerId ?? this.employerId,
      status: status ?? this.status,
      cvUrl: cvUrl ?? this.cvUrl,
      coverLetter: coverLetter ?? this.coverLetter,
      appliedAt: appliedAt ?? this.appliedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ApplicationModel.fromMap(Map<String, dynamic> map) {
    return ApplicationModel(
      appId: map['appId'] as String? ?? '',
      jobId: map['jobId'] as String? ?? '',
      candidateId: map['candidateId'] as String? ?? '',
      employerId: map['employerId'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      cvUrl: map['cvUrl'] as String?,
      coverLetter: map['coverLetter'] as String?,
      appliedAt: (map['appliedAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appId': appId,
      'jobId': jobId,
      'candidateId': candidateId,
      'employerId': employerId,
      'status': status,
      if (cvUrl != null) 'cvUrl': cvUrl,
      if (coverLetter != null) 'coverLetter': coverLetter,
      'appliedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

// ── Snapshot của ứng viên (đọc từ `users` collection) ─────────────────────────
class CandidateSnapshot {
  final String uid;
  final String role;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final double averageRating;
  final int totalJobsDone;

  const CandidateSnapshot({
    required this.uid,
    this.role = 'candidate',
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.averageRating = 0.0,
    this.totalJobsDone = 0,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isCandidate => role == 'candidate';

  factory CandidateSnapshot.fromMap(String uid, Map<String, dynamic> map) {
    return CandidateSnapshot(
      uid: uid,
      role: (map['role'] ?? 'candidate').toString(),
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String?,
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalJobsDone: (map['totalJobsDone'] as int?) ?? 0,
    );
  }
}

// ── Kết hợp đơn + thông tin ứng viên ────────────────────────────────────────
class ApplicationEntry {
  final ApplicationModel application;
  final CandidateSnapshot candidate;

  const ApplicationEntry({required this.application, required this.candidate});

  ApplicationEntry copyWithStatus(String newStatus) {
    return ApplicationEntry(
      application: application.copyWith(status: newStatus),
      candidate: candidate,
    );
  }
}

// ── Job kèm danh sách đơn ứng tuyển ─────────────────────────────────────────
class JobWithApplications {
  final JobPostModel job;
  final List<ApplicationEntry> entries;

  const JobWithApplications({required this.job, required this.entries});

  int get pendingCount {
    final overflowIds = overflowPendingApplicationIds;
    return entries
        .where(
          (e) =>
              e.application.status == 'pending' &&
              !overflowIds.contains(e.application.appId),
        )
        .length;
  }

  int get acceptedCount =>
      entries.where((e) => e.application.status == 'accepted').length;

  Set<String> get overflowPendingApplicationIds {
    if (job.slots <= 0 || job.filledSlots >= job.slots) {
      return entries
          .where((e) => e.application.status == 'pending')
          .map((e) => e.application.appId)
          .toSet();
    }
    return const <String>{};
  }

  JobWithApplications copyWithEntries(List<ApplicationEntry> newEntries) {
    return JobWithApplications(job: job, entries: newEntries);
  }

  JobWithApplications copyWithJob(JobPostModel newJob) {
    return JobWithApplications(job: newJob, entries: entries);
  }
}
