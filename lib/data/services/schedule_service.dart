import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viecnow/data/models/job_post_model.dart';
import 'package:viecnow/data/models/schedule_model.dart';

/// Đọc/ghi lịch làm từ Firestore `schedules`.
class ScheduleService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('schedules');

  Stream<List<ScheduleModel>> watchByCandidate(String candidateId) {
    if (candidateId.isEmpty) {
      return Stream.value(const []);
    }
    return _col
        .where('candidateId', isEqualTo: candidateId)
        .snapshots()
        .asyncMap((snap) => _enrichSchedules(snap.docs));
  }

  Future<List<ScheduleModel>> fetchByCandidate(String candidateId) async {
    if (candidateId.isEmpty) return [];
    final snap =
        await _col.where('candidateId', isEqualTo: candidateId).get();
    return _enrichSchedules(snap.docs);
  }

  Future<List<ScheduleModel>> _enrichSchedules(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return [];

    final raw = docs
        .map((d) => ScheduleModel.fromMap(d.data(), d.id))
        .toList();

    final jobIds = raw.map((s) => s.jobId).where((id) => id.isNotEmpty).toSet();
    final employerIds =
        raw.map((s) => s.employerId).where((id) => id.isNotEmpty).toSet();

    final jobs = await _loadJobs(jobIds);
    final employers = await _loadEmployerNames(employerIds);

    final list = raw.map((s) {
      final job = jobs[s.jobId];
      return ScheduleModel(
        scheduleId: s.scheduleId,
        jobId: s.jobId,
        candidateId: s.candidateId,
        employerId: s.employerId,
        date: s.date,
        startTime: s.startTime,
        endTime: s.endTime,
        status: s.status,
        jobTitle: s.jobTitle ?? job?.title ?? 'Công việc',
        jobLocation: s.jobLocation ?? job?.locationDisplay ?? '',
        employerName: s.employerName ??
            employers[s.employerId] ??
            'Nhà tuyển dụng',
        createdAt: s.createdAt,
      );
    }).toList();

    list.sort((a, b) {
      final d = a.date.compareTo(b.date);
      if (d != 0) return d;
      return a.startTime.compareTo(b.startTime);
    });
    return list;
  }

  Future<Map<String, JobPostModel>> _loadJobs(Set<String> jobIds) async {
    final map = <String, JobPostModel>{};
    for (final id in jobIds) {
      try {
        final snap = await _db.collection('jobPosts').doc(id).get();
        if (snap.exists && snap.data() != null) {
          map[id] = JobPostModel.fromMap(snap.data()!);
        }
      } catch (_) {}
    }
    return map;
  }

  Future<Map<String, String>> _loadEmployerNames(Set<String> ids) async {
    final map = <String, String>{};
    for (final id in ids) {
      try {
        final snap = await _db.collection('users').doc(id).get();
        final m = snap.data();
        if (m == null) continue;
        final company = m['companyName'] as String?;
        if (company != null && company.trim().isNotEmpty) {
          map[id] = company.trim();
          continue;
        }
        final first = m['firstName'] as String? ?? '';
        final last = m['lastName'] as String? ?? '';
        final name = '$first $last'.trim();
        if (name.isNotEmpty) map[id] = name;
      } catch (_) {}
    }
    return map;
  }

  /// Lọc ca trong khoảng ngày [start, end] (inclusive, theo date string).
  static List<ScheduleModel> filterByDateRange(
    List<ScheduleModel> all,
    DateTime start,
    DateTime end,
  ) {
    final s = _dateKey(start);
    final e = _dateKey(end);
    return all.where((x) => x.date.compareTo(s) >= 0 && x.date.compareTo(e) <= 0).toList();
  }

  static List<ScheduleModel> forDay(List<ScheduleModel> all, DateTime day) {
    final key = _dateKey(day);
    return all.where((x) => x.date == key).toList();
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Tính trạng thái hiển thị từ `status` + ngày/giờ hiện tại.
  static ScheduleDisplayKind displayKind(ScheduleModel s) {
    if (s.status == 'cancelled') return ScheduleDisplayKind.cancelled;
    if (s.status == 'completed') return ScheduleDisplayKind.completed;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final parts = s.date.split('-');
    if (parts.length != 3) return ScheduleDisplayKind.pending;
    final day = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );

    if (day.isBefore(today)) return ScheduleDisplayKind.completed;
    if (day.isAfter(today)) return ScheduleDisplayKind.upcoming;

    final nowMin = now.hour * 60 + now.minute;
    final startMin = _parseMinutes(s.startTime);
    final endMin = _parseMinutes(s.endTime);
    if (startMin == null || endMin == null) return ScheduleDisplayKind.pending;
    if (nowMin < startMin) return ScheduleDisplayKind.upcoming;
    if (nowMin > endMin) return ScheduleDisplayKind.completed;
    return ScheduleDisplayKind.ongoing;
  }

  static int? _parseMinutes(String hhmm) {
    final p = hhmm.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}
