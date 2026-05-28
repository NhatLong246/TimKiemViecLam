import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';
import '../../utils/attendance_capture_helper.dart';

class AttendanceService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _col => _db.collection('attendance');

  // ─── Tạo phiên điểm danh mới ─────────────────────────────────────────────
  Future<String> createSession(AttendanceModel session) async {
    // Duplicate check: (jobId + date) chỉ được 1 record
    final existing = await _col
        .where('jobId', isEqualTo: session.jobId)
        .where('date', isEqualTo: session.date)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final ref = _col.doc();
    await ref.set(session.toMap());
    return ref.id;
  }

  // ─── Cập nhật trạng thái 1 record trong phiên điểm danh ─────────────────
  Future<void> updateRecord(
    String attendanceId,
    int recordIndex,
    AttendanceRecord record,
  ) async {
    // Firestore không hỗ trợ update array element trực tiếp →
    // đọc lại toàn bộ records, cập nhật phần tử, rồi write lại
    final doc = await _col.doc(attendanceId).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final rawRecords = List<Map<String, dynamic>>.from(
      (data['records'] as List).map((r) => Map<String, dynamic>.from(r as Map)),
    );

    if (recordIndex >= 0 && recordIndex < rawRecords.length) {
      rawRecords[recordIndex] = record.toMap();
    }

    await _col.doc(attendanceId).update({'records': rawRecords});
  }

  // ─── Lưu toàn bộ records của 1 phiên ─────────────────────────────────────
  Future<void> saveAllRecords(
    String attendanceId,
    List<AttendanceRecord> records,
  ) async {
    await _col.doc(attendanceId).update({
      'records': records.map((r) => r.toMap()).toList(),
    });
  }

  // ─── Stream điểm danh theo job ────────────────────────────────────────────
  Stream<List<AttendanceModel>> streamByJob(String jobId) {
    return _col
        .where('jobId', isEqualTo: jobId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                AttendanceModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  // ─── Lấy phiên điểm danh theo ngày + job ─────────────────────────────────
  /// Ứng viên gửi ảnh điểm danh sau khi NTD yêu cầu.
  Future<AttendanceRecord> submitAttendancePhoto({
    required String attendanceId,
    required String candidateId,
    required bool isCheckIn,
    required String photoBase64,
    required String expectedStartTime,
    required AttendanceCaptureMeta captureMeta,
  }) async {
    final doc = await _col.doc(attendanceId).get();
    if (!doc.exists) throw Exception('Không tìm thấy phiên điểm danh');

    final data = doc.data() as Map<String, dynamic>;
    final rawRecords = List<Map<String, dynamic>>.from(
      (data['records'] as List?)?.map(
            (e) => Map<String, dynamic>.from(e as Map),
          ) ??
          [],
    );

    final idx = rawRecords.indexWhere(
      (r) => (r['candidateId'] ?? '').toString() == candidateId,
    );
    if (idx < 0) throw Exception('Bạn không có trong danh sách điểm danh');

    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);
    final record = Map<String, dynamic>.from(rawRecords[idx]);

    if (isCheckIn) {
      final lateMin = _lateMinutes(now, expectedStartTime);
      final status = lateMin <= 0 ? 'on_time' : 'late';
      record['checkInTime'] = timeStr;
      record['checkInAt'] = Timestamp.fromDate(now);
      record['checkInPhotoUrl'] = photoBase64;
      record['checkInPhotoName'] = captureMeta.fileName;
      record['checkInCapturedAt'] = captureMeta.capturedAt;
      record['checkInLocation'] = captureMeta.locationLabel;
      if (captureMeta.latitude != null) {
        record['checkInLat'] = captureMeta.latitude;
      }
      if (captureMeta.longitude != null) {
        record['checkInLng'] = captureMeta.longitude;
      }
      record['status'] = status;
      record['lateMinutes'] = lateMin > 0 ? lateMin : 0;
    } else {
      if ((record['checkInTime'] ?? '').toString().isEmpty) {
        throw Exception('Hãy điểm danh đầu ca trước');
      }
      record['checkOutTime'] = timeStr;
      record['checkOutAt'] = Timestamp.fromDate(now);
      record['checkOutPhotoUrl'] = photoBase64;
      record['checkOutPhotoName'] = captureMeta.fileName;
      record['checkOutCapturedAt'] = captureMeta.capturedAt;
      record['checkOutLocation'] = captureMeta.locationLabel;
      if (captureMeta.latitude != null) {
        record['checkOutLat'] = captureMeta.latitude;
      }
      if (captureMeta.longitude != null) {
        record['checkOutLng'] = captureMeta.longitude;
      }
      if ((record['status'] ?? 'not_marked') == 'not_marked') {
        record['status'] = 'on_time';
      }
    }

    rawRecords[idx] = record;
    await _col.doc(attendanceId).update({'records': rawRecords});

    return AttendanceRecord.fromMap(record);
  }

  /// Phút trễ so với giờ bắt đầu ca (0 nếu đúng giờ hoặc sớm).
  static int _lateMinutes(DateTime now, String expectedHHmm) {
    final parts = expectedHHmm.split(':');
    if (parts.length < 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final expected = DateTime(now.year, now.month, now.day, h, m);
    final diff = now.difference(expected).inMinutes;
    return diff > 0 ? diff : 0;
  }

  /// Đảm bảo nhân viên có trong phiên điểm danh hôm nay (tạo phiên nếu chưa có).
  Future<String> ensureCandidateRecord({
    required String jobId,
    required String groupId,
    required String employerId,
    required String candidateId,
    required String candidateName,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    var session = await getSessionByDate(jobId, today);

    if (session == null) {
      return createSession(
        AttendanceModel(
          attendanceId: '',
          jobId: jobId,
          groupId: groupId,
          employerId: employerId,
          date: today,
          expectedStartTime: DateFormat('HH:mm').format(DateTime.now()),
          records: [
            AttendanceRecord(
              candidateId: candidateId,
              candidateName: candidateName,
              status: 'not_marked',
              lateMinutes: 0,
            ),
          ],
          createdAt: DateTime.now(),
        ),
      );
    }

    final has = session.records.any((r) => r.candidateId == candidateId);
    if (has) return session.attendanceId;

    final updated = [
      ...session.records,
      AttendanceRecord(
        candidateId: candidateId,
        candidateName: candidateName,
        status: 'not_marked',
        lateMinutes: 0,
      ),
    ];
    await saveAllRecords(session.attendanceId, updated);
    return session.attendanceId;
  }

  Future<List<AttendanceModel>> fetchAllByJob(String jobId) async {
    final snap = await _col.where('jobId', isEqualTo: jobId).get();
    final list = snap.docs
        .map((d) =>
            AttendanceModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<AttendanceModel?> getSessionByDate(String jobId, String date) async {
    final snap = await _col
        .where('jobId', isEqualTo: jobId)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return AttendanceModel.fromMap(
      snap.docs.first.data() as Map<String, dynamic>,
      snap.docs.first.id,
    );
  }
}
