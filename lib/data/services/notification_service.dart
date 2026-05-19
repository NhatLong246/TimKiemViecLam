import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_notification_model.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference get _legacyCol => _db.collection('notifications');

  CollectionReference<Map<String, dynamic>>? _userNotificationsCol(String uid) {
    return _db.collection('users').doc(uid).collection('notifications');
  }

  // ── Employer legacy (top-level `notifications` collection) ─────────────────

  Future<void> create({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    await _legacyCol.add({
      'recipientId': recipientId,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<NotificationModel>> streamByRecipient(String recipientId) {
    return _legacyCol
        .where('recipientId', isEqualTo: recipientId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => NotificationModel.fromMap(
                  d.data() as Map<String, dynamic>,
                  d.id,
                ),
              )
              .toList(),
        );
  }

  Future<void> markLegacyRead(String notifId) async {
    await _legacyCol.doc(notifId).update({'isRead': true});
  }

  Future<void> markAllReadForRecipient(String recipientId) async {
    final snap = await _legacyCol
        .where('recipientId', isEqualTo: recipientId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteLegacy(String notifId) async {
    await _legacyCol.doc(notifId).delete();
  }

  Future<void> clearLegacyRead(String recipientId) async {
    final snap = await _legacyCol
        .where('recipientId', isEqualTo: recipientId)
        .where('isRead', isEqualTo: true)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── User inbox (users/{uid}/notifications subcollection) ───────────────────

  Stream<List<AppNotificationItem>> streamNotifications() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _userNotificationsCol(uid)!
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AppNotificationItem.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<int> streamUnreadCount() {
    return streamNotifications()
        .map((list) => list.where((n) => !n.isRead).length);
  }

  Future<void> markRead(String notificationId) async {
    final uid = _uid;
    if (uid == null) return;
    await _userNotificationsCol(uid)!.doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    final snap = await _userNotificationsCol(uid)!
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    final uid = _uid;
    if (uid == null) return;
    await _userNotificationsCol(uid)!.doc(notificationId).delete();
  }

  Future<void> deleteAll() async {
    final uid = _uid;
    if (uid == null) return;
    final snap = await _userNotificationsCol(uid)!.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<Map<String, bool>> loadPrefs() async {
    final uid = _uid;
    if (uid == null) return _defaultPrefs;

    final doc = await _db.collection('users').doc(uid).get();
    final raw = doc.data()?['notificationPrefs'];
    if (raw is! Map) return _defaultPrefs;

    return {
      'job': raw['job'] != false,
      'system': raw['system'] != false,
      'promo': raw['promo'] == true,
      'profile': raw['profile'] != false,
    };
  }

  Future<void> savePrefs(Map<String, bool> prefs) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set(
      {'notificationPrefs': prefs, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  static const _defaultPrefs = {
    'job': true,
    'system': true,
    'promo': false,
    'profile': true,
  };

  Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    NotificationCategory category = NotificationCategory.system,
  }) async {
    final prefs = await _loadPrefsForUser(userId);
    if (!_isCategoryEnabled(prefs, category)) return;

    await _userNotificationsCol(userId)!.add({
      'title': title,
      'body': body,
      'category': category.name,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, bool>> _loadPrefsForUser(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final raw = doc.data()?['notificationPrefs'];
    if (raw is! Map) return _defaultPrefs;
    return {
      'job': raw['job'] != false,
      'system': raw['system'] != false,
      'promo': raw['promo'] == true,
      'profile': raw['profile'] != false,
    };
  }

  bool _isCategoryEnabled(
    Map<String, bool> prefs,
    NotificationCategory category,
  ) {
    switch (category) {
      case NotificationCategory.job:
        return prefs['job'] ?? true;
      case NotificationCategory.system:
        return prefs['system'] ?? true;
      case NotificationCategory.promo:
        return prefs['promo'] ?? false;
      case NotificationCategory.profile:
        return prefs['profile'] ?? true;
    }
  }

  static Future<void> notifyApplicationAccepted({
    required String candidateId,
    required String jobTitle,
    String? employerName,
  }) async {
    final svc = NotificationService();
    final name =
        employerName?.trim().isNotEmpty == true ? employerName! : 'Nhà tuyển dụng';
    await svc.sendToUser(
      userId: candidateId,
      title: 'Đơn ứng tuyển được chấp nhận',
      body:
          '$name đã chấp nhận bạn cho vị trí "$jobTitle". Mở tin nhắn để trao đổi.',
      category: NotificationCategory.job,
    );
  }

  static Future<void> notifyNewApplication({
    required String employerId,
    required String jobTitle,
    required String candidateName,
  }) async {
    final svc = NotificationService();
    await svc.sendToUser(
      userId: employerId,
      title: 'Có đơn ứng tuyển mới',
      body: '$candidateName vừa ứng tuyển "$jobTitle".',
      category: NotificationCategory.job,
    );
  }
}
