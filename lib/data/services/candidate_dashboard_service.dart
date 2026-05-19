import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/application_model.dart';
import '../models/candidate_dashboard_models.dart';
import '../models/job_post_model.dart';

class CandidateDashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

    final jobIds = apps.map((a) => a.jobId).where((id) => id.isNotEmpty).toSet().toList();
    final employerIds =
        apps.map((a) => a.employerId).where((id) => id.isNotEmpty).toSet().toList();

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
      final da = a.application.updatedAt ??
          a.application.appliedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.application.updatedAt ??
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

  CandidatePayment _rowToPayment(_AcceptedJobRow row) {
    final jobClosed = row.job.status == 'closed';
    final paidAt = jobClosed
        ? (row.application.updatedAt ?? row.application.appliedAt)
        : null;

    return CandidatePayment(
      id: row.application.appId,
      jobTitle: row.job.title,
      employerName: row.employerName,
      amountVnd: row.job.salary.round(),
      status: jobClosed ? 'paid' : 'pending',
      paidAt: paidAt,
      benefitNote: row.job.salaryDisplay,
    );
  }

  Future<List<CandidatePayment>> fetchPayments() async {
    final rows = await _fetchAcceptedRows();
    return rows.map(_rowToPayment).toList();
  }

  Future<List<ReviewableJob>> fetchReviewableJobs() async {
    final rows = await _fetchAcceptedRows();
    return rows
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

  Future<List<WorkGroup>> fetchWorkGroups() async {
    final col = _groupsCol;
    if (col == null) return [];

    final snap = await col.get();
    final list =
        snap.docs.map((d) => WorkGroup.fromMap(d.id, d.data())).toList();
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
  }) async {
    var paid = 0;
    var pending = 0;
    var hours = 0.0;

    final rows = await _fetchAcceptedRows();
    final hoursByAppId = <String, double>{};
    for (final row in rows) {
      hoursByAppId[row.application.appId] =
          row.job.workHoursPerDay ?? 4.0;
    }

    for (final p in payments) {
      if (p.status == 'paid') {
        paid += p.amountVnd;
        hours += hoursByAppId[p.id] ?? 4.0;
      } else if (p.status == 'pending') {
        pending += p.amountVnd;
      }
    }

    return CandidateEarningsSummary(
      totalPaidVnd: paid,
      pendingVnd: pending,
      jobCount: payments.where((p) => p.status == 'paid').length,
      hoursWorked: hours.round(),
      avgRating: profileRating,
    );
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
