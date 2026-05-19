import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/work_schedule_model.dart';

class WorkScheduleService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _col => _db.collection('workSchedules');

  // ─── Tạo hoặc cập nhật lịch làm việc theo ngày + nhóm ────────────────────
  Future<String> saveSchedule(WorkScheduleModel schedule) async {
    // Kiểm tra đã có lịch cho ngày + nhóm này chưa
    final existing = await _col
        .where('groupId', isEqualTo: schedule.groupId)
        .where('date', isEqualTo: schedule.date)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final id = existing.docs.first.id;
      await _col.doc(id).update(schedule.toMap());
      return id;
    }

    final ref = _col.doc();
    await ref.set(schedule.toMap());
    return ref.id;
  }

  // ─── Lấy lịch theo ngày + nhóm ───────────────────────────────────────────
  Future<WorkScheduleModel?> getByDate(String groupId, String date) async {
    final snap = await _col
        .where('groupId', isEqualTo: groupId)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return WorkScheduleModel.fromMap(
        snap.docs.first.data() as Map<String, dynamic>, snap.docs.first.id);
  }

  // ─── Stream danh sách lịch của nhóm (sắp xếp theo ngày) ─────────────────
  Stream<List<WorkScheduleModel>> streamByGroup(String groupId) {
    return _col
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => WorkScheduleModel.fromMap(
              d.data() as Map<String, dynamic>, d.id))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  // ─── Xóa lịch ─────────────────────────────────────────────────────────────
  Future<void> delete(String scheduleId) async {
    await _col.doc(scheduleId).delete();
  }
}
