import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';

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
