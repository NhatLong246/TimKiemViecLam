import 'dart:async';
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

    final controller = StreamController<List<ScheduleModel>>.broadcast();
    List<ScheduleModel> explicitSchedules = [];
    List<ScheduleModel> appliedSchedules = [];

    void emit() {
      final map = <String, ScheduleModel>{};
      for (final s in appliedSchedules) {
        map['${s.jobId}_${s.date}'] = s;
      }
      for (final s in explicitSchedules) {
        map['${s.jobId}_${s.date}'] = s;
      }

      final list = map.values.toList();
      list.sort((a, b) {
        final d = a.date.compareTo(b.date);
        if (d != 0) return d;
        return a.startTime.compareTo(b.startTime);
      });
      if (!controller.isClosed) {
        controller.add(list);
      }
    }

    final sub1 = _col
        .where('candidateId', isEqualTo: candidateId)
        .snapshots()
        .asyncMap((snap) => _enrichSchedules(snap.docs))
        .listen((data) {
          explicitSchedules = data;
          emit();
        });

    final sub2 = _db
        .collection('applications')
        .where('candidateId', isEqualTo: candidateId)
        .where('status', whereIn: ['pending', 'accepted'])
        .snapshots()
        .asyncMap(
          (snap) => _enrichApplicationsToSchedules(candidateId, snap.docs),
        )
        .listen((data) {
          appliedSchedules = data;
          emit();
        });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    return controller.stream;
  }

  Future<List<ScheduleModel>> fetchByCandidate(String candidateId) async {
    if (candidateId.isEmpty) return [];
    final snap = await _col.where('candidateId', isEqualTo: candidateId).get();
    return _enrichSchedules(snap.docs);
  }

  Future<List<ScheduleModel>> fetchAllSchedules(String candidateId) async {
    if (candidateId.isEmpty) return [];

    final explicitDocs = await _col
        .where('candidateId', isEqualTo: candidateId)
        .get();
    final explicitList = await _enrichSchedules(explicitDocs.docs);

    final appDocs = await _db
        .collection('applications')
        .where('candidateId', isEqualTo: candidateId)
        .where('status', whereIn: ['pending', 'accepted'])
        .get();
    final appList = await _enrichApplicationsToSchedules(
      candidateId,
      appDocs.docs,
    );

    final map = <String, ScheduleModel>{};
    for (final s in appList) {
      map['${s.jobId}_${s.date}'] = s;
    }
    for (final s in explicitList) {
      map['${s.jobId}_${s.date}'] = s;
    }
    return map.values.toList();
  }

  Future<List<ScheduleModel>> _enrichSchedules(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return [];

    final raw = docs.map((d) => ScheduleModel.fromMap(d.data(), d.id)).toList();

    final jobIds = raw.map((s) => s.jobId).where((id) => id.isNotEmpty).toSet();
    final employerIds = raw
        .map((s) => s.employerId)
        .where((id) => id.isNotEmpty)
        .toSet();

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
        employerName:
            s.employerName ?? employers[s.employerId] ?? 'Nhà tuyển dụng',
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

  Future<List<ScheduleModel>> _enrichApplicationsToSchedules(
    String candidateId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return [];

    final jobIds = docs
        .map((d) => d.data()['jobId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final jobs = await _loadJobs(jobIds);

    final employerIds = jobs.values.map((j) => j.employerId).toSet();
    final employers = await _loadEmployerNames(employerIds);

    final list = <ScheduleModel>[];

    for (final doc in docs) {
      final appId = doc.id;
      final data = doc.data();
      final jobId = data['jobId'] as String? ?? '';
      final appStatus = data['status'] as String? ?? 'pending';

      final job = jobs[jobId];
      if (job == null) continue;

      final empName = employers[job.employerId] ?? 'Nhà tuyển dụng';

      final startDate = job.startDate;
      final endDate = job.endDate ?? startDate;

      final limitDays = 60;
      var current = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);

      int count = 0;
      while ((current.isBefore(end) || current.isAtSameMomentAs(end)) &&
          count < limitDays) {
        final dateKey = _dateKey(current);

        final startTime = job.startTime ?? '08:00';
        final workHours = job.workHoursPerDay ?? 8.0;
        final h = (workHours).floor();
        final m = ((workHours - h) * 60).round();

        String endTime = '17:00';
        final p = startTime.split(':');
        if (p.length == 2) {
          final sh = int.tryParse(p[0]) ?? 8;
          final sm = int.tryParse(p[1]) ?? 0;
          final totalM = sh * 60 + sm + h * 60 + m;
          final eh = (totalM ~/ 60) % 24;
          final em = totalM % 60;
          endTime =
              '${eh.toString().padLeft(2, '0')}:${em.toString().padLeft(2, '0')}';
        }

        list.add(
          ScheduleModel(
            scheduleId: 'app_${appId}_$dateKey',
            jobId: jobId,
            candidateId: candidateId,
            employerId: job.employerId,
            date: dateKey,
            startTime: startTime,
            endTime: endTime,
            status: appStatus == 'pending' ? 'pending' : 'scheduled',
            jobTitle: job.title,
            jobLocation: job.locationDisplay,
            employerName: empName,
            createdAt: data['createdAt'] != null
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now(),
          ),
        );

        current = current.add(const Duration(days: 1));
        count++;
      }
    }

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
    return all
        .where((x) => x.date.compareTo(s) >= 0 && x.date.compareTo(e) <= 0)
        .toList();
  }

  static List<ScheduleModel> forDay(List<ScheduleModel> all, DateTime day) {
    final key = _dateKey(day);
    return all.where((x) => x.date == key).toList();
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Tính trạng thái hiển thị từ `status` + ngày/giờ hiện tại.
  static ScheduleDisplayKind displayKind(ScheduleModel s) {
    if (s.status == 'pending') return ScheduleDisplayKind.pending;
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

  /// Kiểm tra lịch làm việc của candidate có bị trùng với job này không.
  /// Throws Exception nếu bị trùng.
  Future<void> checkOverlap(String candidateId, JobPostModel newJob) async {
    final existingSchedules = await fetchAllSchedules(candidateId);

    // Tạo danh sách ngày dự kiến cho newJob
    final startDate = newJob.startDate;
    final endDate = newJob.endDate ?? startDate;

    final startTime = newJob.startTime ?? '08:00';
    final workHours = newJob.workHoursPerDay ?? 8.0;
    final h = workHours.floor();
    final m = ((workHours - h) * 60).round();

    String endTime = '17:00';
    final p = startTime.split(':');
    if (p.length == 2) {
      final sh = int.tryParse(p[0]) ?? 8;
      final sm = int.tryParse(p[1]) ?? 0;
      final totalM = sh * 60 + sm + h * 60 + m;
      final eh = (totalM ~/ 60) % 24;
      final em = totalM % 60;
      endTime =
          '${eh.toString().padLeft(2, '0')}:${em.toString().padLeft(2, '0')}';
    }

    final newStartMin = _parseMinutes(startTime) ?? 0;
    final newEndMin = _parseMinutes(endTime) ?? 0;

    var current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    int limitDays = 60;
    int count = 0;

    while ((current.isBefore(end) || current.isAtSameMomentAs(end)) &&
        count < limitDays) {
      final dateKey = _dateKey(current);

      // Check in existing schedules
      for (final s in existingSchedules) {
        if (s.jobId == newJob.jobId) continue; // Bỏ qua trùng với chính job này
        if (s.date == dateKey &&
            s.status != 'cancelled' &&
            s.status != 'completed' &&
            s.status != 'pending') {
          final sStartMin = _parseMinutes(s.startTime) ?? 0;
          final sEndMin = _parseMinutes(s.endTime) ?? 0;

          // Trùng khi (NewStart < OldEnd) && (NewEnd > OldStart)
          if (newStartMin < sEndMin && newEndMin > sStartMin) {
            throw Exception(
              'Lịch trùng vào ngày ${s.date} (Ca: ${s.startTime}-${s.endTime}). Vui lòng kiểm tra lại!',
            );
          }
        }
      }
      current = current.add(const Duration(days: 1));
      count++;
    }
  }
}
