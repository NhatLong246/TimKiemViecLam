import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/job_post_model.dart';

class WorkShiftWindow {
  final String date;
  final int startMin;
  final int endMin;
  final String startTime;
  final String endTime;

  const WorkShiftWindow({
    required this.date,
    required this.startMin,
    required this.endMin,
    required this.startTime,
    required this.endTime,
  });
}

class ScheduleLockService {
  ScheduleLockService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const int maxGeneratedDays = 60;

  CollectionReference<Map<String, dynamic>> get _locks =>
      _db.collection('candidateScheduleLocks');

  static List<WorkShiftWindow> buildShiftWindows(JobPostModel job) {
    final windows = <WorkShiftWindow>[];
    final startDate = job.startDate;
    final endDate = job.endDate ?? startDate;
    final startTime = job.startTime ?? '08:00';
    final durationMinutes = ((job.workHoursPerDay ?? 8.0) * 60).round();
    final startMin = parseMinutes(startTime) ?? 8 * 60;

    var current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    var count = 0;

    while ((current.isBefore(end) || current.isAtSameMomentAs(end)) &&
        count < maxGeneratedDays) {
      var remaining = durationMinutes;
      var segmentDate = current;
      var segmentStart = startMin;

      while (remaining > 0) {
        final availableToday = 1440 - segmentStart;
        final segmentLength = remaining < availableToday
            ? remaining
            : availableToday;
        final segmentEnd = segmentStart + segmentLength;

        if (segmentLength > 0) {
          windows.add(
            WorkShiftWindow(
              date: dateKey(segmentDate),
              startMin: segmentStart,
              endMin: segmentEnd,
              startTime: formatMinutes(segmentStart),
              endTime: formatMinutes(segmentEnd),
            ),
          );
        }

        remaining -= segmentLength;
        if (remaining <= 0) break;
        segmentDate = segmentDate.add(const Duration(days: 1));
        segmentStart = 0;
      }

      current = current.add(const Duration(days: 1));
      count++;
    }

    return windows;
  }

  static bool jobsOverlap(JobPostModel a, JobPostModel b) {
    final aWindows = buildShiftWindows(a);
    final bWindows = buildShiftWindows(b);

    for (final left in aWindows) {
      for (final right in bWindows) {
        if (left.date != right.date) continue;
        if (overlaps(
          left.startMin,
          left.endMin,
          right.startMin,
          right.endMin,
        )) {
          return true;
        }
      }
    }
    return false;
  }

  static bool overlaps(int startA, int endA, int startB, int endB) {
    return startA < endB && endA > startB;
  }

  static int? parseMinutes(String hhmm) {
    final p = hhmm.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static String formatMinutes(int minutes) {
    final normalized = minutes.clamp(0, 1440).toInt();
    final h = (normalized ~/ 60) % 24;
    final m = normalized % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> acquireLocksInTransaction({
    required Transaction tx,
    required String candidateId,
    required String appId,
    required String jobId,
    required String employerId,
    required String jobTitle,
    required List<WorkShiftWindow> windows,
  }) async {
    if (windows.isEmpty) {
      throw Exception('Công việc thiếu lịch làm để khóa thời gian.');
    }

    final refs = {
      for (final window in windows)
        window.date: _lockRef(candidateId, window.date),
    };
    final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final entry in refs.entries) {
      snapshots[entry.key] = await tx.get(entry.value);
    }

    for (final window in windows) {
      final snap = snapshots[window.date];
      final existing = _locksFromSnapshot(snap);
      for (final lock in existing) {
        final lockedAppId = (lock['appId'] ?? '').toString();
        if (lockedAppId == appId) continue;
        final lockedStart = (lock['startMin'] as num?)?.toInt();
        final lockedEnd = (lock['endMin'] as num?)?.toInt();
        if (lockedStart == null || lockedEnd == null) continue;
        if (overlaps(window.startMin, window.endMin, lockedStart, lockedEnd)) {
          final lockedTitle = (lock['jobTitle'] ?? 'công việc khác').toString();
          final lockedStartText = (lock['startTime'] ?? '').toString();
          final lockedEndText = (lock['endTime'] ?? '').toString();
          throw Exception(
            'Ứng viên đã có lịch làm "$lockedTitle" trùng ngày '
            '${window.date} ($lockedStartText-$lockedEndText).',
          );
        }
      }
    }

    final createdAt = Timestamp.now();
    for (final window in windows) {
      final ref = refs[window.date]!;
      final snap = snapshots[window.date];
      final existing = _locksFromSnapshot(snap);
      final nextLocks = [
        ...existing,
        {
          'candidateId': candidateId,
          'appId': appId,
          'jobId': jobId,
          'employerId': employerId,
          'jobTitle': jobTitle,
          'startMin': window.startMin,
          'endMin': window.endMin,
          'startTime': window.startTime,
          'endTime': window.endTime,
          'createdAt': createdAt,
        },
      ];

      tx.set(ref, {
        'candidateId': candidateId,
        'date': window.date,
        'locks': nextLocks,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> releaseLocksForApplication({
    required String candidateId,
    required String appId,
    required JobPostModel job,
  }) async {
    if (candidateId.isEmpty || appId.isEmpty) return;
    final windows = buildShiftWindows(job);
    if (windows.isEmpty) return;

    await _db.runTransaction((tx) async {
      await releaseLocksInTransaction(
        tx: tx,
        candidateId: candidateId,
        appId: appId,
        windows: windows,
      );
    });
  }

  Future<void> releaseLocksInTransaction({
    required Transaction tx,
    required String candidateId,
    required String appId,
    required List<WorkShiftWindow> windows,
  }) async {
    if (candidateId.isEmpty || appId.isEmpty || windows.isEmpty) return;

    final refs = {
      for (final window in windows)
        window.date: _lockRef(candidateId, window.date),
    };
    final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final entry in refs.entries) {
      snapshots[entry.key] = await tx.get(entry.value);
    }

    for (final entry in snapshots.entries) {
      final ref = refs[entry.key]!;
      final existing = _locksFromSnapshot(entry.value);
      final nextLocks = existing
          .where((lock) => (lock['appId'] ?? '').toString() != appId)
          .toList();

      if (nextLocks.length == existing.length) continue;
      if (nextLocks.isEmpty) {
        tx.delete(ref);
      } else {
        tx.update(ref, {
          'locks': nextLocks,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  DocumentReference<Map<String, dynamic>> _lockRef(
    String candidateId,
    String date,
  ) {
    return _locks.doc('${candidateId}_$date');
  }

  List<Map<String, dynamic>> _locksFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>>? snap,
  ) {
    final data = snap?.data();
    final rawLocks = data?['locks'];
    if (rawLocks is! List) return <Map<String, dynamic>>[];
    return rawLocks
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
