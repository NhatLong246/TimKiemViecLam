import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection('notifications');

  // ── Tạo thông báo mới ──────────────────────────────────────────────────────
  Future<void> create({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    await _col.add({
      'recipientId': recipientId,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Stream thông báo theo người nhận (realtime) ───────────────────────────
  Stream<List<NotificationModel>> streamByRecipient(String recipientId) {
    return _col
        .where('recipientId', isEqualTo: recipientId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                NotificationModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  // ── Đánh dấu 1 thông báo đã đọc ─────────────────────────────────────────
  Future<void> markRead(String notifId) async {
    await _col.doc(notifId).update({'isRead': true});
  }

  // ── Đánh dấu tất cả đã đọc ───────────────────────────────────────────────
  Future<void> markAllRead(String recipientId) async {
    final snap = await _col
        .where('recipientId', isEqualTo: recipientId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ── Xóa 1 thông báo ──────────────────────────────────────────────────────
  Future<void> delete(String notifId) async {
    await _col.doc(notifId).delete();
  }

  // ── Xóa tất cả thông báo đã đọc của 1 user ───────────────────────────────
  Future<void> clearRead(String recipientId) async {
    final snap = await _col
        .where('recipientId', isEqualTo: recipientId)
        .where('isRead', isEqualTo: true)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
